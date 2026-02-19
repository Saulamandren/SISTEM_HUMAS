# File: backend/app/utils/security.py

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError, InvalidHash
import re
from datetime import datetime, timedelta
import jwt
from functools import wraps
from flask import request, jsonify, current_app
import MySQLdb.cursors

# Initialize Argon2 Password Hasher
ph = PasswordHasher(
    time_cost=3,        # Number of iterations
    memory_cost=65536,  # Memory usage in KB (64 MB)
    parallelism=4,      # Number of parallel threads
    hash_len=32,        # Length of the hash in bytes
    salt_len=16         # Length of the salt in bytes
)


def hash_password(password: str) -> str:
    """
    Hash a password using Argon2id algorithm
    
    Args:
        password (str): Plain text password
        
    Returns:
        str: Hashed password
    """
    try:
        return ph.hash(password)
    except Exception as e:
        raise ValueError(f"Error hashing password: {str(e)}")


def verify_password(hashed_password: str, plain_password: str) -> bool:
    """
    Verify a password against its hash
    
    Args:
        hashed_password (str): The Argon2 hashed password
        plain_password (str): The plain text password to verify
        
    Returns:
        bool: True if password matches, False otherwise
    """
    try:
        ph.verify(hashed_password, plain_password)
        
        # Check if rehashing is needed (parameters changed)
        if ph.check_needs_rehash(hashed_password):
            return "rehash_needed"
        
        return True
    except VerifyMismatchError:
        return False
    except (VerificationError, InvalidHash) as e:
        print(f"Password verification error: {str(e)}")
        return False


def validate_password_strength(password: str) -> tuple:
    """
    Validate password strength
    
    Requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    
    Args:
        password (str): Password to validate
        
    Returns:
        tuple: (is_valid: bool, message: str)
    """
    if len(password) < 8:
        return False, "Password harus minimal 8 karakter"
    
    if not re.search(r'[A-Z]', password):
        return False, "Password harus mengandung minimal 1 huruf kapital"
    
    if not re.search(r'[a-z]', password):
        return False, "Password harus mengandung minimal 1 huruf kecil"
    
    if not re.search(r'\d', password):
        return False, "Password harus mengandung minimal 1 angka"
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False, "Password harus mengandung minimal 1 karakter khusus (!@#$%^&*(),.?\":{}|<>)"
    
    return True, "Password valid"


def generate_jwt_token(user_id: int, username: str, role: str) -> dict:
    """
    Generate JWT access and refresh tokens
    
    Args:
        user_id (int): User ID
        username (str): Username
        role (str): User role
        
    Returns:
        dict: Dictionary containing access_token and refresh_token
    """
    try:
        access_token_expires = current_app.config['JWT_ACCESS_TOKEN_EXPIRES']
        refresh_token_expires = current_app.config['JWT_REFRESH_TOKEN_EXPIRES']
        
        # Access token payload
        access_payload = {
            'user_id': user_id,
            'username': username,
            'role': role,
            'type': 'access',
            'exp': datetime.utcnow() + access_token_expires,
            'iat': datetime.utcnow()
        }
        
        # Refresh token payload
        refresh_payload = {
            'user_id': user_id,
            'username': username,
            'type': 'refresh',
            'exp': datetime.utcnow() + refresh_token_expires,
            'iat': datetime.utcnow()
        }
        
        access_token = jwt.encode(
            access_payload,
            current_app.config['JWT_SECRET_KEY'],
            algorithm='HS256'
        )
        
        refresh_token = jwt.encode(
            refresh_payload,
            current_app.config['JWT_SECRET_KEY'],
            algorithm='HS256'
        )
        
        return {
            'access_token': access_token,
            'refresh_token': refresh_token,
            'expires_in': int(access_token_expires.total_seconds())
        }
    except Exception as e:
        raise ValueError(f"Error generating tokens: {str(e)}")


def decode_jwt_token(token: str) -> dict:
    """
    Decode and verify JWT token
    
    Args:
        token (str): JWT token
        
    Returns:
        dict: Decoded token payload
        
    Raises:
        jwt.ExpiredSignatureError: If token has expired
        jwt.InvalidTokenError: If token is invalid
    """
    try:
        payload = jwt.decode(
            token,
            current_app.config['JWT_SECRET_KEY'],
            algorithms=['HS256']
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise jwt.ExpiredSignatureError("Token telah kadaluarsa")
    except jwt.InvalidTokenError as e:
        raise jwt.InvalidTokenError(f"Token tidak valid: {str(e)}")


def token_required(f):
    """
    Decorator to protect routes with JWT authentication
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Get token from header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            try:
                token = auth_header.split(" ")[1]  # Bearer <token>
            except IndexError:
                return jsonify({
                    'status': 'error',
                    'message': 'Format token tidak valid. Gunakan: Bearer <token>'
                }), 401
        
        if not token:
            return jsonify({
                'status': 'error',
                'message': 'Token tidak ditemukan. Silakan login terlebih dahulu.'
            }), 401
        
        try:
            # Decode token
            payload = decode_jwt_token(token)
            
            # Check token type
            if payload.get('type') != 'access':
                return jsonify({
                    'status': 'error',
                    'message': 'Token type tidak valid'
                }), 401
            
            # Get current user from database
            from app import mysql
            cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
            cursor.execute('''
                SELECT u.*, r.role_name 
                FROM users u 
                JOIN roles r ON u.role_id = r.id 
                WHERE u.id = %s AND u.is_active = TRUE
            ''', (payload['user_id'],))
            current_user = cursor.fetchone()
            cursor.close()
            
            if not current_user:
                return jsonify({
                    'status': 'error',
                    'message': 'User tidak ditemukan atau tidak aktif'
                }), 401
            
            # Add current_user to kwargs
            kwargs['current_user'] = current_user
            
        except jwt.ExpiredSignatureError:
            return jsonify({
                'status': 'error',
                'message': 'Token telah kadaluarsa. Silakan login kembali.'
            }), 401
        except jwt.InvalidTokenError as e:
            return jsonify({
                'status': 'error',
                'message': f'Token tidak valid: {str(e)}'
            }), 401
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': f'Terjadi kesalahan: {str(e)}'
            }), 500
        
        return f(*args, **kwargs)
    
    return decorated


def role_required(allowed_roles: list):
    """
    Decorator to check if user has required role
    
    Args:
        allowed_roles (list): List of allowed role names
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            current_user = kwargs.get('current_user')
            
            if not current_user:
                return jsonify({
                    'status': 'error',
                    'message': 'User tidak terautentikasi'
                }), 401
            
            if current_user['role_name'] not in allowed_roles:
                return jsonify({
                    'status': 'error',
                    'message': 'Anda tidak memiliki akses ke resource ini'
                }), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def sanitize_input(data: str) -> str:
    """
    Sanitize user input to prevent XSS
    
    Args:
        data (str): Input string
        
    Returns:
        str: Sanitized string
    """
    if not isinstance(data, str):
        return data
    
    # Remove potential XSS patterns
    dangerous_patterns = [
        r'<script.*?>.*?</script>',
        r'javascript:',
        r'onerror=',
        r'onload=',
        r'onclick='
    ]
    
    sanitized = data
    for pattern in dangerous_patterns:
        sanitized = re.sub(pattern, '', sanitized, flags=re.IGNORECASE)
    
    return sanitized.strip()
