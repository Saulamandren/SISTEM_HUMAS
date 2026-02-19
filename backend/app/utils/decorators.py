from functools import wraps
from functools import wraps
from flask import request, jsonify, current_app
import jwt
from app.models.user import User

def token_required(f):
    """Decorator to require valid JWT token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Get token from header
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            try:
                token = auth_header.split(' ')[1]  # Bearer <token>
            except IndexError:
                return jsonify({
                    'status': 'error',
                    'message': 'Invalid token format'
                }), 401
        
        if not token:
            return jsonify({
                'status': 'error',
                'message': 'Token is required'
            }), 401
        
        try:
            # Decode token
            payload = jwt.decode(
                token,
                current_app.config['JWT_SECRET_KEY'],
                algorithms=['HS256']
            )
            
            # Get user
            user_model = User()
            result = user_model.get_user_by_id(payload['user_id'])
            
            if not result['success']:
                return jsonify({
                    'status': 'error',
                    'message': 'User not found'
                }), 401
            
            # Attach user to request
            request.current_user = result['user']
            
        except jwt.ExpiredSignatureError:
            return jsonify({
                'status': 'error',
                'message': 'Token has expired'
            }), 401
        except jwt.InvalidTokenError:
            return jsonify({
                'status': 'error',
                'message': 'Invalid token'
            }), 401
        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': f'Token verification failed: {str(e)}'
            }), 401
        
        return f(*args, **kwargs)
    
    return decorated


def permission_required(permission_name):
    """Decorator to check if user has specific permission"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if not hasattr(request, 'current_user'):
                return jsonify({
                    'status': 'error',
                    'message': 'Authentication required'
                }), 401
            
            # Get user permissions from database
            import MySQLdb
            try:
                conn = MySQLdb.connect(
                    host=current_app.config['MYSQL_HOST'],
                    port=current_app.config['MYSQL_PORT'],
                    user=current_app.config['MYSQL_USER'],
                    password=current_app.config['MYSQL_PASSWORD'],
                    database=current_app.config['MYSQL_DB']
                )
                cursor = conn.cursor()
                
                query = """
                    SELECT p.permission_name
                    FROM permissions p
                    JOIN role_permissions rp ON p.id = rp.permission_id
                    JOIN users u ON u.role_id = rp.role_id
                    WHERE u.id = %s AND p.permission_name = %s
                """
                cursor.execute(query, (request.current_user['id'], permission_name))
                
                has_permission = cursor.fetchone() is not None
                
                cursor.close()
                conn.close()
                
                if not has_permission:
                    return jsonify({
                        'status': 'error',
                        'message': 'You do not have permission to perform this action'
                    }), 403
                
            except Exception as e:
                return jsonify({
                    'status': 'error',
                    'message': f'Permission check failed: {str(e)}'
                }), 500
            
            return f(*args, **kwargs)
        
        return decorated
    
    return decorator


def role_required(*roles):
    """Decorator to check if user has specific role"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if not hasattr(request, 'current_user'):
                return jsonify({
                    'status': 'error',
                    'message': 'Authentication required'
                }), 401
            
            user_role = request.current_user.get('role', '')
            
            if user_role not in roles:
                return jsonify({
                    'status': 'error',
                    'message': f'Access denied. Required role: {", ".join(roles)}'
                }), 403
            
            return f(*args, **kwargs)
        
        return decorated
    
    return decorator
