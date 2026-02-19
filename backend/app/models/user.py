import MySQLdb
from flask import current_app
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
import jwt
import datetime

# Initialize Argon2 password hasher
ph = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16
)

class User:
    """User model for authentication and user management"""
    
    def __init__(self):
        self.conn = None
        self.cursor = None
    
    def _get_db_connection(self):
        """Get database connection"""
        try:
            self.conn = MySQLdb.connect(
                host=current_app.config['MYSQL_HOST'],
                port=current_app.config['MYSQL_PORT'],
                user=current_app.config['MYSQL_USER'],
                password=current_app.config['MYSQL_PASSWORD'],
                database=current_app.config['MYSQL_DB']
            )
            self.cursor = self.conn.cursor(MySQLdb.cursors.DictCursor)
            print(f"[DB] Connection established to {current_app.config['MYSQL_DB']}")
        except Exception as e:
            print(f"[DB ERROR] Connection failed: {str(e)}")
            raise Exception(f"Database connection failed: {str(e)}")
    
    def _close_db_connection(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("[DB] Connection closed")
    
    def create_user(self, username, email, password, full_name, nip=None, role_id=1):
        """Create a new user"""
        try:
            self._get_db_connection()
            
            print(f"[CREATE USER] Attempting to create user: {username}")
            
            # Check if username exists
            self.cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            if self.cursor.fetchone():
                print(f"[CREATE USER] Username already exists: {username}")
                return {'success': False, 'message': 'Username already exists'}
            
            # Check if email exists
            self.cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
            if self.cursor.fetchone():
                print(f"[CREATE USER] Email already exists: {email}")
                return {'success': False, 'message': 'Email already exists'}
            
            # Hash password
            password_hash = ph.hash(password)
            print(f"[CREATE USER] Password hashed successfully")
            
            # Insert user
            query = """
                INSERT INTO users (username, email, password_hash, full_name, nip, role_id, is_active, email_verified)
                VALUES (%s, %s, %s, %s, %s, %s, TRUE, FALSE)
            """
            self.cursor.execute(query, (username, email, password_hash, full_name, nip, role_id))
            self.conn.commit()
            
            user_id = self.cursor.lastrowid
            print(f"[CREATE USER] User created successfully with ID: {user_id}")
            
            return {'success': True, 'user_id': user_id}
            
        except Exception as e:
            print(f"[CREATE USER ERROR] {str(e)}")
            if self.conn:
                self.conn.rollback()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def authenticate(self, username, password):
        """Authenticate user and return user data with tokens"""
        try:
            self._get_db_connection()
            
            print(f"[AUTH] Attempting to authenticate user: {username}")
            
            # Get user by username or email
            query = """
                SELECT u.*, r.role_name
                FROM users u
                JOIN roles r ON u.role_id = r.id
                WHERE (u.username = %s OR u.email = %s) AND u.is_active = TRUE
            """
            self.cursor.execute(query, (username, username))
            user = self.cursor.fetchone()
            
            if not user:
                print(f"[AUTH] User not found or inactive: {username}")
                return {'success': False, 'message': 'Invalid username or password'}
            
            print(f"[AUTH] User found: {user['username']} (ID: {user['id']})")
            print(f"[AUTH] Verifying password...")
            
            # Verify password
            try:
                ph.verify(user['password_hash'], password)
                print(f"[AUTH] Password verified successfully")
            except VerifyMismatchError:
                print(f"[AUTH] Password verification failed")
                return {'success': False, 'message': 'Invalid username or password'}
            
            # Update last login
            self.cursor.execute("UPDATE users SET last_login = NOW() WHERE id = %s", (user['id'],))
            self.conn.commit()
            print(f"[AUTH] Last login updated")
            
            # Generate JWT tokens
            access_token = self._generate_token(user['id'], 'access')
            refresh_token = self._generate_token(user['id'], 'refresh')
            print(f"[AUTH] Tokens generated")
            
            # Prepare user data with proper type conversion
            user_data = {
                'id': int(user['id']),
                'username': str(user['username']),
                'email': str(user['email']),
                'full_name': str(user['full_name']),
                'nip': str(user['nip']) if user['nip'] else None,
                'role': str(user['role_name']),
                'is_active': bool(user['is_active']),  # Convert to boolean
                'email_verified': bool(user['email_verified']),  # Convert to boolean
                'last_login': user['last_login'].isoformat() if user['last_login'] else None,
                'created_at': user['created_at'].isoformat() if user['created_at'] else None
            }
            
            print(f"[AUTH] Authentication successful for user: {username}")
            
            return {
                'success': True,
                'data': {
                    'user': user_data,
                    'tokens': {
                        'access_token': access_token,
                        'refresh_token': refresh_token,
                        'expires_in': current_app.config['JWT_ACCESS_TOKEN_EXPIRES']
                    }
                }
            }
            
        except Exception as e:
            print(f"[AUTH ERROR] {str(e)}")
            import traceback
            traceback.print_exc()
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
    
    def _generate_token(self, user_id, token_type='access'):
        """Generate JWT token"""
        try:
            if token_type == 'access':
                expires_in = current_app.config['JWT_ACCESS_TOKEN_EXPIRES']
            else:
                expires_in = current_app.config['JWT_REFRESH_TOKEN_EXPIRES']
            
            payload = {
                'user_id': user_id,
                'type': token_type,
                'exp': datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in),
                'iat': datetime.datetime.utcnow()
            }
            
            token = jwt.encode(
                payload, 
                current_app.config['JWT_SECRET_KEY'], 
                algorithm='HS256'
            )
            
            print(f"[TOKEN] Generated {token_type} token for user_id: {user_id}")
            
            return token
            
        except Exception as e:
            print(f"[TOKEN ERROR] Failed to generate token: {str(e)}")
            raise
    
    def verify_token(self, token):
        """Verify JWT token and return payload"""
        try:
            payload = jwt.decode(
                token,
                current_app.config['JWT_SECRET_KEY'],
                algorithms=['HS256']
            )
            print(f"[TOKEN] Token verified for user_id: {payload.get('user_id')}")
            return {'success': True, 'payload': payload}
        except jwt.ExpiredSignatureError:
            print(f"[TOKEN] Token expired")
            return {'success': False, 'message': 'Token has expired'}
        except jwt.InvalidTokenError as e:
            print(f"[TOKEN] Invalid token: {str(e)}")
            return {'success': False, 'message': 'Invalid token'}
    
    def get_user_by_id(self, user_id):
        """Get user by ID"""
        try:
            self._get_db_connection()
            
            query = """
                SELECT u.*, r.role_name
                FROM users u
                JOIN roles r ON u.role_id = r.id
                WHERE u.id = %s
            """
            self.cursor.execute(query, (user_id,))
            user = self.cursor.fetchone()
            
            if not user:
                return {'success': False, 'message': 'User not found'}
            
            user_data = {
                'id': int(user['id']),
                'username': str(user['username']),
                'email': str(user['email']),
                'full_name': str(user['full_name']),
                'nip': str(user['nip']) if user['nip'] else None,
                'role': str(user['role_name']),
                'is_active': bool(user['is_active']),
                'email_verified': bool(user['email_verified']),
                'last_login': user['last_login'].isoformat() if user['last_login'] else None,
                'created_at': user['created_at'].isoformat() if user['created_at'] else None
            }
            
            return {'success': True, 'user': user_data}
            
        except Exception as e:
            print(f"[GET USER ERROR] {str(e)}")
            return {'success': False, 'message': str(e)}
        finally:
            self._close_db_connection()
