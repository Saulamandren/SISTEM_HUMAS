from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'dev-secret-key-change-me'
    app.config['DEBUG'] = True
    
    CORS(app)
    
    @app.route('/health')
    def health():
        return jsonify({
            'status': 'success',
            'message': 'Backend ready!',
            'data': None
        }), 200
    
    @app.route('/api/auth/login', methods=['POST'])
    def login():
        return jsonify({
            'status': 'success',
            'message': 'Login successful',
            'data': {
                'access_token': 'dummy-jwt-token-12345',
                'user': {
                    'id': 1,
                    'username': 'admin',
                    'full_name': 'Administrator',
                    'email': 'admin@poltek.ac.id',
                    'role': 'Kasubbag Jashumas',
                    'is_staff': True,
                    'is_kasubbag': True,
                    'is_active': True,
                    'created_at': '2026-02-18T22:00:00Z'
                }
            }
        }), 200
    
    @app.route('/api/categories/')
    def categories():
        return jsonify({
            'status': 'success',
            'message': 'Categories retrieved successfully',
            'data': [
                {
                    'id': 1,
                    'name': 'Berita Kampus',
                    'slug': 'berita-kampus',
                    'description': 'Berita dan informasi kampus',
                    'icon': 'newspaper',
                    'color': '#1976D2',
                    'is_active': True,
                    'created_by': 1,
                    'created_at': '2026-02-01T10:00:00Z'
                },
                {
                    'id': 2,
                    'name': 'Pengumuman',
                    'slug': 'pengumuman',
                    'description': 'Pengumuman resmi',
                    'icon': 'campaign',
                    'color': '#F57C00',
                    'is_active': True,
                    'created_by': 1,
                    'created_at': '2026-02-01T10:00:00Z'
                },
                {
                    'id': 3,
                    'name': 'Artikel',
                    'slug': 'artikel',
                    'description': 'Artikel opini dan pandangan',
                    'icon': 'article',
                    'color': '#388E3C',
                    'is_active': True,
                    'created_by': 1,
                    'created_at': '2026-02-01T10:00:00Z'
                }
            ]
        }), 200
    
    @app.route('/api/contents/')
    def contents():
        return jsonify({
            'status': 'success',
            'message': 'Contents retrieved successfully',
            'data': {
                'contents': [],
                'pagination': {
                    'page': 1,
                    'per_page': 10,
                    'total': 0,
                    'total_pages': 0
                }
            }
        }), 200
    
    @app.route('/api/contents/<int:content_id>')
    def content_detail(content_id):
        return jsonify({
            'status': 'success',
            'data': {
                'id': content_id,
                'title': 'Sample Content',
                'slug': 'sample-content',
                'body': 'This is sample content body.',
                'excerpt': 'Sample excerpt',
                'category_id': 1,
                'category_name': 'Berita Kampus',
                'author_id': 1,
                'author_name': 'Administrator',
                'status': 'draft',
                'status_text': 'Draft',
                'views': 0,
                'published_at': None,
                'created_at': '2026-02-18T22:00:00Z',
                'updated_at': '2026-02-18T22:00:00Z'
            }
        }), 200
    
    return app
