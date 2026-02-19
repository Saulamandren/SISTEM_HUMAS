from flask import Blueprint, request, jsonify
from app.utils.validators import validate_email, validate_password
from app.models.user import User
from app.utils.response import success_response, error_response
import MySQLdb
from flask import current_app

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    """User registration endpoint"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['username', 'email', 'password', 'full_name']
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)
        
        username = data['username'].strip()
        email = data['email'].strip()
        password = data['password']
        full_name = data['full_name'].strip()
        nip = data.get('nip', '').strip() if data.get('nip') else None
        role_id = data.get('role_id', 1)  # Default: User role
        
        # Validate email format
        if not validate_email(email):
            return error_response('Invalid email format', 400)
        
        # Validate password strength
        password_valid, password_msg = validate_password(password)
        if not password_valid:
            return error_response(password_msg, 400)
        
        # Create user
        user = User()
        result = user.create_user(
            username=username,
            email=email,
            password=password,
            full_name=full_name,
            nip=nip,
            role_id=role_id
        )
        
        if result['success']:
            return success_response('User registered successfully', result['user_id'], 201)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        current_app.logger.error(f"Registration error: {str(e)}")
        return error_response(f'Registration failed: {str(e)}', 500)


@auth_bp.route('/login', methods=['POST'])
def login():
    """User login endpoint"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('username') or not data.get('password'):
            return error_response('Username and password are required', 400)
        
        username = data['username'].strip()
        password = data['password']
        
        # Authenticate user
        user = User()
        result = user.authenticate(username, password)
        
        if result['success']:
            return success_response('Login successful', result['data'], 200)
        else:
            return error_response(result['message'], 401)
            
    except Exception as e:
        current_app.logger.error(f"Login error: {str(e)}")
        return error_response(f'Login failed: {str(e)}', 500)


@auth_bp.route('/logout', methods=['POST'])
def logout():
    """User logout endpoint"""
    try:
        # Get token from header
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return error_response('Token is required', 400)
        
        # Invalidate session (if using session management)
        # For now, just return success (client will delete token)
        
        return success_response('Logout successful', None, 200)
            
    except Exception as e:
        current_app.logger.error(f"Logout error: {str(e)}")
        return error_response(f'Logout failed: {str(e)}', 500)


@auth_bp.route('/profile', methods=['GET'])
def get_profile():
    """Get user profile endpoint"""
    try:
        # Get token from header
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not token:
            return error_response('Token is required', 401)
        
        # TODO: Decode JWT and get user_id
        # For now, return mock data
        
        return error_response('Not implemented yet', 501)
            
    except Exception as e:
        current_app.logger.error(f"Get profile error: {str(e)}")
        return error_response(f'Failed to get profile: {str(e)}', 500)
