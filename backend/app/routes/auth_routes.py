# File: backend/app/routes/auth_routes.py

from flask import Blueprint, request, jsonify, current_app
from app import mysql
from app.utils.security import (
    hash_password, verify_password, validate_password_strength,
    generate_jwt_token, decode_jwt_token, token_required, sanitize_input
)
from app.utils.validators import (
    validate_username, validate_email_format, validate_nip, 
    validate_full_name, validate_role_id
)
from app.utils.email_service import EmailService
import MySQLdb.cursors
from datetime import datetime, timedelta
import json

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

# Rate limiting storage (simple in-memory, use Redis in production)
login_attempts = {}


def check_rate_limit(identifier: str) -> tuple:
    """
    Check if identifier (IP or username) has exceeded rate limit
    
    Returns:
        tuple: (is_allowed: bool, remaining_attempts: int, reset_time: datetime)
    """
    now = datetime.now()
    max_attempts = current_app.config['RATE_LIMIT_LOGIN']
    window_seconds = current_app.config['RATE_LIMIT_WINDOW']
    
    if identifier not in login_attempts:
        login_attempts[identifier] = {
            'attempts': 0,
            'reset_time': now + timedelta(seconds=window_seconds)
        }
    
    attempt_data = login_attempts[identifier]
    
    # Reset if window has passed
    if now > attempt_data['reset_time']:
        login_attempts[identifier] = {
            'attempts': 0,
            'reset_time': now + timedelta(seconds=window_seconds)
        }
        attempt_data = login_attempts[identifier]
    
    # Check limit
    if attempt_data['attempts'] >= max_attempts:
        return False, 0, attempt_data['reset_time']
    
    remaining = max_attempts - attempt_data['attempts']
    return True, remaining, attempt_data['reset_time']


def record_login_attempt(identifier: str):
    """Record a failed login attempt"""
    if identifier in login_attempts:
        login_attempts[identifier]['attempts'] += 1
    else:
        login_attempts[identifier] = {
            'attempts': 1,
            'reset_time': datetime.now() + timedelta(seconds=current_app.config['RATE_LIMIT_WINDOW'])
        }


def log_audit(user_id, action, module, details, ip_address, user_agent):
    """Log activity to audit_logs table"""
    try:
        cursor = mysql.connection.cursor()
        cursor.execute('''
            INSERT INTO audit_logs (user_id, action, module, ip_address, user_agent, details)
            VALUES (%s, %s, %s, %s, %s, %s)
        ''', (user_id, action, module, ip_address, user_agent, json.dumps(details)))
        mysql.connection.commit()
        cursor.close()
    except Exception as e:
        print(f"Error logging audit: {str(e)}")


@auth_bp.route('/register', methods=['POST'])
def register():
    """
    Register new user
    
    Request Body:
        {
            "username": "string",
            "email": "string",
            "password": "string",
            "full_name": "string",
            "nip": "string" (optional),
            "role_id": int
        }
    """
    try:
        data = request.get_json()
        
        # Extract and sanitize inputs
        username = sanitize_input(data.get('username', '')).lower()
        email = sanitize_input(data.get('email', '')).lower()
        password = data.get('password', '')
        full_name = sanitize_input(data.get('full_name', ''))
        nip = sanitize_input(data.get('nip', '')) if data.get('nip') else None
        role_id = data.get('role_id', 1)  # Default to User role
        
        # Validate inputs
        valid, msg = validate_username(username)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        valid, msg, normalized_email = validate_email_format(email)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        email = normalized_email
        
        valid, msg = validate_password_strength(password)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        valid, msg = validate_full_name(full_name)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        if nip:
            valid, msg = validate_nip(nip)
            if not valid:
                return jsonify({'status': 'error', 'message': msg}), 400
        
        # Get valid role IDs
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('SELECT id FROM roles')
        valid_roles = [row['id'] for row in cursor.fetchall()]
        
        valid, msg = validate_role_id(role_id, valid_roles)
        if not valid:
            cursor.close()
            return jsonify({'status': 'error', 'message': msg}), 400
        
        # Check if username already exists
        cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
        if cursor.fetchone():
            cursor.close()
            return jsonify({
                'status': 'error',
                'message': 'Username sudah terdaftar'
            }), 409
        
        # Check if email already exists
        cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
        if cursor.fetchone():
            cursor.close()
            return jsonify({
                'status': 'error',
                'message': 'Email sudah terdaftar'
            }), 409
        
        # Check if NIP already exists (if provided)
        if nip:
            cursor.execute('SELECT id FROM users WHERE nip = %s', (nip,))
            if cursor.fetchone():
                cursor.close()
                return jsonify({
                    'status': 'error',
                    'message': 'NIP sudah terdaftar'
                }), 409
        
        # Hash password
        password_hash = hash_password(password)
        
        # Insert user
        cursor.execute('''
            INSERT INTO users (username, email, password_hash, full_name, nip, role_id, is_active, email_verified)
            VALUES (%s, %s, %s, %s, %s, %s, TRUE, FALSE)
        ''', (username, email, password_hash, full_name, nip, role_id))
        
        mysql.connection.commit()
        user_id = cursor.lastrowid
        cursor.close()
        
        # Log audit
        log_audit(
            user_id, 
            'USER_REGISTERED', 
            'user',
            {'username': username, 'email': email},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        # Send welcome email (async in production)
        try:
            EmailService.send_welcome_email(email, full_name, username)
        except Exception as e:
            print(f"Failed to send welcome email: {str(e)}")
        
        return jsonify({
            'status': 'success',
            'message': 'Registrasi berhasil. Silakan login dengan akun Anda.',
            'data': {
                'user_id': user_id,
                'username': username,
                'email': email
            }
        }), 201
        
    except Exception as e:
        print(f"Registration error: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/login', methods=['POST'])
def login():
    """
    User login
    
    Request Body:
        {
            "username": "string",  # can be username or email
            "password": "string"
        }
    """
    try:
        data = request.get_json()
        identifier = sanitize_input(data.get('username', '')).lower()
        password = data.get('password', '')
        
        if not identifier or not password:
            return jsonify({
                'status': 'error',
                'message': 'Username dan password harus diisi'
            }), 400
        
        # Check rate limit
        ip_address = request.remote_addr
        is_allowed, remaining, reset_time = check_rate_limit(ip_address)
        
        if not is_allowed:
            return jsonify({
                'status': 'error',
                'message': f'Terlalu banyak percobaan login. Coba lagi pada {reset_time.strftime("%H:%M:%S")}'
            }), 429
        
        # Find user by username or email
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('''
            SELECT u.*, r.role_name 
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE (u.username = %s OR u.email = %s) AND u.is_active = TRUE
        ''', (identifier, identifier))
        
        user = cursor.fetchone()
        
        if not user:
            record_login_attempt(ip_address)
            cursor.close()
            return jsonify({
                'status': 'error',
                'message': 'Username/email atau password salah',
                'remaining_attempts': remaining - 1
            }), 401
        
        # Verify password
        is_valid = verify_password(user['password_hash'], password)
        
        if not is_valid:
            record_login_attempt(ip_address)
            cursor.close()
            return jsonify({
                'status': 'error',
                'message': 'Username/email atau password salah',
                'remaining_attempts': remaining - 1
            }), 401
        
        # Generate tokens
        tokens = generate_jwt_token(user['id'], user['username'], user['role_name'])
        
        # Save session
        user_agent = request.headers.get('User-Agent', 'Unknown')
        cursor.execute('''
            INSERT INTO sessions (user_id, token, refresh_token, ip_address, user_agent, expires_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        ''', (
            user['id'],
            tokens['access_token'],
            tokens['refresh_token'],
            ip_address,
            user_agent,
            datetime.now() + current_app.config['JWT_ACCESS_TOKEN_EXPIRES']
        ))
        
        # Update last login
        cursor.execute('UPDATE users SET last_login = %s WHERE id = %s', (datetime.now(), user['id']))
        mysql.connection.commit()
        cursor.close()
        
        # Clear rate limit on successful login
        if ip_address in login_attempts:
            del login_attempts[ip_address]
        
        # Log audit
        log_audit(
            user['id'],
            'USER_LOGIN',
            'user',
            {'username': user['username'], 'success': True},
            ip_address,
            user_agent
        )
        
        # Send login notification email (async in production)
        try:
            EmailService.send_login_notification(
                user['email'], 
                user['full_name'],
                ip_address,
                user_agent
            )
        except Exception as e:
            print(f"Failed to send login notification: {str(e)}")
        
        return jsonify({
            'status': 'success',
            'message': 'Login berhasil',
            'data': {
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'email': user['email'],
                    'full_name': user['full_name'],
                    'role': user['role_name'],
                    'nip': user['nip']
                },
                'tokens': tokens
            }
        }), 200
        
    except Exception as e:
        print(f"Login error: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/logout', methods=['POST'])
@token_required
def logout(current_user):
    """Logout user and invalidate token"""
    try:
        # Get token from header
        token = request.headers.get('Authorization').split(" ")[1]
        
        # Delete session
        cursor = mysql.connection.cursor()
        cursor.execute('DELETE FROM sessions WHERE user_id = %s AND token = %s', 
                      (current_user['id'], token))
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'USER_LOGOUT',
            'user',
            {'username': current_user['username']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'Logout berhasil'
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/refresh', methods=['POST'])
def refresh_token():
    """Refresh access token using refresh token"""
    try:
        data = request.get_json()
        refresh_token = data.get('refresh_token')
        
        if not refresh_token:
            return jsonify({
                'status': 'error',
                'message': 'Refresh token tidak ditemukan'
            }), 400
        
        # Decode refresh token
        try:
            payload = decode_jwt_token(refresh_token)
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': 'Refresh token tidak valid atau telah kadaluarsa'
            }), 401
        
        # Check token type
        if payload.get('type') != 'refresh':
            return jsonify({
                'status': 'error',
                'message': 'Token type tidak valid'
            }), 401
        
        # Get user
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('''
            SELECT u.*, r.role_name 
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = %s AND u.is_active = TRUE
        ''', (payload['user_id'],))
        
        user = cursor.fetchone()
        cursor.close()
        
        if not user:
            return jsonify({
                'status': 'error',
                'message': 'User tidak ditemukan'
            }), 401
        
        # Generate new tokens
        new_tokens = generate_jwt_token(user['id'], user['username'], user['role_name'])
        
        return jsonify({
            'status': 'success',
            'message': 'Token berhasil diperbarui',
            'data': {
                'tokens': new_tokens
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/profile', methods=['GET'])
@token_required
def get_profile(current_user):
    """Get current user profile"""
    try:
        return jsonify({
            'status': 'success',
            'data': {
                'id': current_user['id'],
                'username': current_user['username'],
                'email': current_user['email'],
                'full_name': current_user['full_name'],
                'nip': current_user['nip'],
                'role': current_user['role_name'],
                'is_active': current_user['is_active'],
                'email_verified': current_user['email_verified'],
                'last_login': current_user['last_login'].isoformat() if current_user['last_login'] else None,
                'created_at': current_user['created_at'].isoformat()
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/profile', methods=['PUT'])
@token_required
def update_profile(current_user):
    """Update user profile (non-password fields)"""
    try:
        data = request.get_json()
        
        # Fields that can be updated
        full_name = sanitize_input(data.get('full_name', current_user['full_name']))
        email = sanitize_input(data.get('email', current_user['email'])).lower()
        nip = sanitize_input(data.get('nip', current_user['nip'])) if data.get('nip') else current_user['nip']
        
        # Validate
        valid, msg = validate_full_name(full_name)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        valid, msg, normalized_email = validate_email_format(email)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        email = normalized_email
        
        if nip:
            valid, msg = validate_nip(nip)
            if not valid:
                return jsonify({'status': 'error', 'message': msg}), 400
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        
        # Check if email is taken by another user
        if email != current_user['email']:
            cursor.execute('SELECT id FROM users WHERE email = %s AND id != %s', (email, current_user['id']))
            if cursor.fetchone():
                cursor.close()
                return jsonify({
                    'status': 'error',
                    'message': 'Email sudah digunakan oleh user lain'
                }), 409
        
        # Check if NIP is taken by another user
        if nip and nip != current_user['nip']:
            cursor.execute('SELECT id FROM users WHERE nip = %s AND id != %s', (nip, current_user['id']))
            if cursor.fetchone():
                cursor.close()
                return jsonify({
                    'status': 'error',
                    'message': 'NIP sudah digunakan oleh user lain'
                }), 409
        
        # Update profile
        cursor.execute('''
            UPDATE users 
            SET full_name = %s, email = %s, nip = %s, updated_at = %s
            WHERE id = %s
        ''', (full_name, email, nip, datetime.now(), current_user['id']))
        
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'PROFILE_UPDATED',
            'user',
            {'fields_updated': ['full_name', 'email', 'nip']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'Profile berhasil diperbarui',
            'data': {
                'full_name': full_name,
                'email': email,
                'nip': nip
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@auth_bp.route('/change-password', methods=['POST'])
@token_required
def change_password(current_user):
    """Change user password"""
    try:
        data = request.get_json()
        old_password = data.get('old_password', '')
        new_password = data.get('new_password', '')
        confirm_password = data.get('confirm_password', '')
        
        if not all([old_password, new_password, confirm_password]):
            return jsonify({
                'status': 'error',
                'message': 'Semua field harus diisi'
            }), 400
        
        # Verify old password
        if not verify_password(current_user['password_hash'], old_password):
            return jsonify({
                'status': 'error',
                'message': 'Password lama tidak sesuai'
            }), 401
        
        # Check if new password same as old
        if old_password == new_password:
            return jsonify({
                'status': 'error',
                'message': 'Password baru harus berbeda dengan password lama'
            }), 400
        
        # Validate new password
        valid, msg = validate_password_strength(new_password)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        # Check password confirmation
        if new_password != confirm_password:
            return jsonify({
                'status': 'error',
                'message': 'Konfirmasi password tidak sesuai'
            }), 400
        
        # Hash new password
        new_password_hash = hash_password(new_password)
        
        # Update password
        cursor = mysql.connection.cursor()
        cursor.execute('''
            UPDATE users 
            SET password_hash = %s, updated_at = %s
            WHERE id = %s
        ''', (new_password_hash, datetime.now(), current_user['id']))
        
        # Invalidate all existing sessions for security
        cursor.execute('DELETE FROM sessions WHERE user_id = %s', (current_user['id'],))
        
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'PASSWORD_CHANGED',
            'user',
            {'username': current_user['username']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        # Send email notification
        try:
            EmailService.send_password_changed_notification(
                current_user['email'],
                current_user['full_name']
            )
        except Exception as e:
            print(f"Failed to send password change notification: {str(e)}")
        
        return jsonify({
            'status': 'success',
            'message': 'Password berhasil diubah. Silakan login kembali.'
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500
