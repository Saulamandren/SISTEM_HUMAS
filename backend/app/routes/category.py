from flask import Blueprint, request, jsonify
from app.models.category import Category
from app.utils.decorators import token_required, permission_required
from app.utils.response import success_response, error_response

category_bp = Blueprint('category', __name__)

@category_bp.route('/', methods=['GET'])
@token_required
def get_categories():
    """Get all categories"""
    try:
        active_only = request.args.get('active_only', 'true').lower() == 'true'
        
        category = Category()
        result = category.get_all_categories(active_only=active_only)
        
        if result['success']:
            return success_response('Categories retrieved successfully', result['categories'], 200)
        else:
            return error_response(result['message'], 500)
            
    except Exception as e:
        return error_response(f'Failed to get categories: {str(e)}', 500)


@category_bp.route('/<int:category_id>', methods=['GET'])
@token_required
def get_category(category_id):
    """Get category by ID"""
    try:
        category = Category()
        result = category.get_category_by_id(category_id)
        
        if result['success']:
            return success_response('Category retrieved successfully', result['category'], 200)
        else:
            return error_response(result['message'], 404)
            
    except Exception as e:
        return error_response(f'Failed to get category: {str(e)}', 500)


@category_bp.route('/', methods=['POST'])
@token_required
@permission_required('category.create')
def create_category():
    """Create new category"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'description']
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)
        
        name = data['name'].strip()
        description = data['description'].strip()
        icon = data.get('icon', 'article').strip()
        color = data.get('color', '#1976D2').strip()
        created_by = request.current_user['id']
        
        category = Category()
        result = category.create_category(name, description, icon, color, created_by)
        
        if result['success']:
            return success_response('Category created successfully', {'category_id': result['category_id']}, 201)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to create category: {str(e)}', 500)


@category_bp.route('/<int:category_id>', methods=['PUT'])
@token_required
@permission_required('category.update')
def update_category(category_id):
    """Update category"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'description', 'icon', 'color']
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)
        
        name = data['name'].strip()
        description = data['description'].strip()
        icon = data['icon'].strip()
        color = data['color'].strip()
        
        category = Category()
        result = category.update_category(category_id, name, description, icon, color)
        
        if result['success']:
            return success_response('Category updated successfully', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to update category: {str(e)}', 500)


@category_bp.route('/<int:category_id>', methods=['DELETE'])
@token_required
@permission_required('category.delete')
def delete_category(category_id):
    """Delete category"""
    try:
        category = Category()
        result = category.delete_category(category_id)
        
        if result['success']:
            return success_response('Category deleted successfully', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to delete category: {str(e)}', 500)
