# File: backend/app/routes/user_routes.py

from flask import Blueprint, request, jsonify
from app import mysql
from app.utils.security import (
    hash_password, token_required, role_required, sanitize_input
)
from app.utils.validators import (
    validate_username, validate_email_format, validate_nip, 
    validate_full_name, validate_role_id
)
from datetime import datetime
import MySQLdb.cursors
import json

user_bp = Blueprint('user', __name__, url_prefix='/api/users')


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


@user_bp.route('/', methods=['GET'])
@token_required
@role_required(['Staff Jashumas', 'Kasubbag Jashumas'])
def get_all_users(current_user):
    """
    Get all users (with pagination and filters)
    
    Query Parameters:
        - page: int (default: 1)
        - per_page: int (default: 10)
        - role_id: int (optional filter)
        - search: string (optional, search by username/email/name)
        - is_active: boolean (optional filter)
    """
    try:
        # Get query parameters
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 10, type=int)
        role_id = request.args.get('role_id', type=int)
        search = request.args.get('search', '').strip()
        is_active = request.args.get('is_active', type=str)
        
        # Validate pagination
        if page < 1:
            page = 1
        if per_page < 1 or per_page > 100:
            per_page = 10
        
        offset = (page - 1) * per_page
        
        # Build query
        where_clauses = []
        params = []
        
        if role_id:
            where_clauses.append('u.role_id = %s')
            params.append(role_id)
        
        if search:
            where_clauses.append('''
                (u.username LIKE %s OR u.email LIKE %s OR u.full_name LIKE %s OR u.nip LIKE %s)
            ''')
            search_pattern = f'%{search}%'
            params.extend([search_pattern] * 4)
        
        if is_active is not None:
            is_active_bool = is_active.lower() in ['true', '1', 'yes']
            where_clauses.append('u.is_active = %s')
            params.append(is_active_bool)
        
        where_sql = 'WHERE ' + ' AND '.join(where_clauses) if where_clauses else ''
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        
        # Get total count
        count_query = f'''
            SELECT COUNT(*) as total
            FROM users u
            {where_sql}
        '''
        cursor.execute(count_query, params)
        total = cursor.fetchone()['total']
        
        # Get users
        query = f'''
            SELECT 
                u.id, u.username, u.email, u.full_name, u.nip,
                u.is_active, u.email_verified, u.last_login, u.created_at,
                r.role_name, r.description as role_description
            FROM users u
            JOIN roles r ON u.role_id = r.id
            {where_sql}
            ORDER BY u.created_at DESC
            LIMIT %s OFFSET %s
        '''
        cursor.execute(query, params + [per_page, offset])
        users = cursor.fetchall()
        cursor.close()
        
        # Format response
        users_list = []
        for user in users:
            users_list.append({
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'full_name': user['full_name'],
                'nip': user['nip'],
                'role': user['role_name'],
                'role_description': user['role_description'],
                'is_active': bool(user['is_active']),
                'email_verified': bool(user['email_verified']),
                'last_login': user['last_login'].isoformat() if user['last_login'] else None,
                'created_at': user['created_at'].isoformat()
            })
        
        total_pages = (total + per_page - 1) // per_page
        
        return jsonify({
            'status': 'success',
            'data': {
                'users': users_list,
                'pagination': {
                    'page': page,
                    'per_page': per_page,
                    'total': total,
                    'total_pages': total_pages,
                    'has_next': page < total_pages,
                    'has_prev': page > 1
                }
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/<int:user_id>', methods=['GET'])
@token_required
@role_required(['Staff Jashumas', 'Kasubbag Jashumas'])
def get_user_by_id(current_user, user_id):
    """Get user detail by ID"""
    try:
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('''
            SELECT 
                u.id, u.username, u.email, u.full_name, u.nip,
                u.is_active, u.email_verified, u.last_login, u.created_at, u.updated_at,
                r.id as role_id, r.role_name, r.description as role_description
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = %s
        ''', (user_id,))
        
        user = cursor.fetchone()
        cursor.close()
        
        if not user:
            return jsonify({
                'status': 'error',
                'message': 'User tidak ditemukan'
            }), 404
        
        return jsonify({
            'status': 'success',
            'data': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'full_name': user['full_name'],
                'nip': user['nip'],
                'role_id': user['role_id'],
                'role': user['role_name'],
                'role_description': user['role_description'],
                'is_active': bool(user['is_active']),
                'email_verified': bool(user['email_verified']),
                'last_login': user['last_login'].isoformat() if user['last_login'] else None,
                'created_at': user['created_at'].isoformat(),
                'updated_at': user['updated_at'].isoformat()
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/', methods=['POST'])
@token_required
@role_required(['Kasubbag Jashumas'])
def create_user(current_user):
    """
    Create new user (Admin only)
    
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
        
        # Extract and sanitize
        username = sanitize_input(data.get('username', '')).lower()
        email = sanitize_input(data.get('email', '')).lower()
        password = data.get('password', 'DefaultPass123!')  # Default password
        full_name = sanitize_input(data.get('full_name', ''))
        nip = sanitize_input(data.get('nip', '')) if data.get('nip') else None
        role_id = data.get('role_id')
        
        # Validate
        valid, msg = validate_username(username)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        valid, msg, normalized_email = validate_email_format(email)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        email = normalized_email
        
        valid, msg = validate_full_name(full_name)
        if not valid:
            return jsonify({'status': 'error', 'message': msg}), 400
        
        if nip:
            valid, msg = validate_nip(nip)
            if not valid:
                return jsonify({'status': 'error', 'message': msg}), 400
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        
        # Get valid roles
        cursor.execute('SELECT id FROM roles')
        valid_roles = [row['id'] for row in cursor.fetchall()]
        
        valid, msg = validate_role_id(role_id, valid_roles)
        if not valid:
            cursor.close()
            return jsonify({'status': 'error', 'message': msg}), 400
        
        # Check duplicates
        cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
        if cursor.fetchone():
            cursor.close()
            return jsonify({'status': 'error', 'message': 'Username sudah terdaftar'}), 409
        
        cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
        if cursor.fetchone():
            cursor.close()
            return jsonify({'status': 'error', 'message': 'Email sudah terdaftar'}), 409
        
        if nip:
            cursor.execute('SELECT id FROM users WHERE nip = %s', (nip,))
            if cursor.fetchone():
                cursor.close()
                return jsonify({'status': 'error', 'message': 'NIP sudah terdaftar'}), 409
        
        # Hash password
        password_hash = hash_password(password)
        
        # Insert user
        cursor.execute('''
            INSERT INTO users (username, email, password_hash, full_name, nip, role_id, is_active, email_verified)
            VALUES (%s, %s, %s, %s, %s, %s, TRUE, TRUE)
        ''', (username, email, password_hash, full_name, nip, role_id))
        
        mysql.connection.commit()
        new_user_id = cursor.lastrowid
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'USER_CREATED',
            'user',
            {'created_user_id': new_user_id, 'username': username},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'User berhasil dibuat',
            'data': {
                'user_id': new_user_id,
                'username': username,
                'email': email,
                'default_password': password
            }
        }), 201
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/<int:user_id>', methods=['PUT'])
@token_required
@role_required(['Kasubbag Jashumas'])
def update_user(current_user, user_id):
    """Update user data (Admin only)"""
    try:
        data = request.get_json()
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        
        # Check if user exists
        cursor.execute('SELECT * FROM users WHERE id = %s', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            cursor.close()
            return jsonify({'status': 'error', 'message': 'User tidak ditemukan'}), 404
        
        # Get fields to update
        full_name = sanitize_input(data.get('full_name', user['full_name']))
        email = sanitize_input(data.get('email', user['email'])).lower()
        nip = sanitize_input(data.get('nip', user['nip'])) if data.get('nip') else user['nip']
        role_id = data.get('role_id', user['role_id'])
        is_active = data.get('is_active', user['is_active'])
        
        # Validate
        valid, msg = validate_full_name(full_name)
        if not valid:
            cursor.close()
            return jsonify({'status': 'error', 'message': msg}), 400
        
        valid, msg, normalized_email = validate_email_format(email)
        if not valid:
            cursor.close()
            return jsonify({'status': 'error', 'message': msg}), 400
        email = normalized_email
        
        if nip:
            valid, msg = validate_nip(nip)
            if not valid:
                cursor.close()
                return jsonify({'status': 'error', 'message': msg}), 400
        
        # Check duplicates
        if email != user['email']:
            cursor.execute('SELECT id FROM users WHERE email = %s AND id != %s', (email, user_id))
            if cursor.fetchone():
                cursor.close()
                return jsonify({'status': 'error', 'message': 'Email sudah digunakan'}), 409
        
        if nip and nip != user['nip']:
            cursor.execute('SELECT id FROM users WHERE nip = %s AND id != %s', (nip, user_id))
            if cursor.fetchone():
                cursor.close()
                return jsonify({'status': 'error', 'message': 'NIP sudah digunakan'}), 409
        
        # Update user
        cursor.execute('''
            UPDATE users 
            SET full_name = %s, email = %s, nip = %s, role_id = %s, is_active = %s, updated_at = %s
            WHERE id = %s
        ''', (full_name, email, nip, role_id, is_active, datetime.now(), user_id))
        
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'USER_UPDATED',
            'user',
            {'updated_user_id': user_id, 'username': user['username']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'User berhasil diperbarui'
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/<int:user_id>', methods=['DELETE'])
@token_required
@role_required(['Kasubbag Jashumas'])
def delete_user(current_user, user_id):
    """Delete user (Admin only)"""
    try:
        # Prevent self-deletion
        if user_id == current_user['id']:
            return jsonify({
                'status': 'error',
                'message': 'Tidak dapat menghapus akun sendiri'
            }), 400
        
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('SELECT username FROM users WHERE id = %s', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            cursor.close()
            return jsonify({'status': 'error', 'message': 'User tidak ditemukan'}), 404
        
        # Soft delete (set is_active to FALSE) or hard delete
        # Using hard delete here, but soft delete is recommended
        cursor.execute('DELETE FROM users WHERE id = %s', (user_id,))
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'USER_DELETED',
            'user',
            {'deleted_user_id': user_id, 'username': user['username']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'User berhasil dihapus'
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/<int:user_id>/reset-password', methods=['POST'])
@token_required
@role_required(['Kasubbag Jashumas'])
def reset_user_password(current_user, user_id):
    """Reset user password to default (Admin only)"""
    try:
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('SELECT username, email FROM users WHERE id = %s', (user_id,))
        user = cursor.fetchone()
        
        if not user:
            cursor.close()
            return jsonify({'status': 'error', 'message': 'User tidak ditemukan'}), 404
        
        # Generate new default password
        new_password = 'ResetPass123!'
        password_hash = hash_password(new_password)
        
        # Update password
        cursor.execute('''
            UPDATE users 
            SET password_hash = %s, updated_at = %s
            WHERE id = %s
        ''', (password_hash, datetime.now(), user_id))
        
        # Invalidate all sessions
        cursor.execute('DELETE FROM sessions WHERE user_id = %s', (user_id,))
        
        mysql.connection.commit()
        cursor.close()
        
        # Log audit
        log_audit(
            current_user['id'],
            'PASSWORD_RESET',
            'user',
            {'reset_user_id': user_id, 'username': user['username']},
            request.remote_addr,
            request.headers.get('User-Agent', 'Unknown')
        )
        
        return jsonify({
            'status': 'success',
            'message': 'Password berhasil direset',
            'data': {
                'username': user['username'],
                'new_password': new_password
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500


@user_bp.route('/roles', methods=['GET'])
@token_required
def get_roles(current_user):
    """Get all available roles"""
    try:
        cursor = mysql.connection.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute('SELECT id, role_name, description FROM roles ORDER BY id')
        roles = cursor.fetchall()
        cursor.close()
        
        return jsonify({
            'status': 'success',
            'data': {
                'roles': roles
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'Terjadi kesalahan: {str(e)}'
        }), 500
