from flask import Blueprint, request, jsonify
from app.models.content import Content
from app.utils.decorators import token_required, permission_required, role_required
from app.utils.response import success_response, error_response

content_bp = Blueprint('content', __name__)

@content_bp.route('/', methods=['GET'])
@token_required
def get_contents():
    """Get all contents with filters"""
    try:
        # Get query parameters
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 10))
        status = request.args.get('status')
        category_id = request.args.get('category_id')
        author_id = request.args.get('author_id')
        search = request.args.get('search')
        
        # Build filters
        filters = {}
        if status:
            filters['status'] = status
        if category_id:
            filters['category_id'] = int(category_id)
        if author_id:
            filters['author_id'] = int(author_id)
        if search:
            filters['search'] = search
        
        # Check permissions
        user = request.current_user
        
        # If user doesn't have 'read all' permission, show only their content
        # (This is simplified - you can add proper permission check)
        if user['role'] == 'User':
            filters['author_id'] = user['id']
        
        content = Content()
        result = content.get_contents(filters, page, per_page)
        
        if result['success']:
            return success_response('Contents retrieved successfully', result, 200)
        else:
            return error_response(result['message'], 500)
            
    except Exception as e:
        return error_response(f'Failed to get contents: {str(e)}', 500)


@content_bp.route('/<int:content_id>', methods=['GET'])
@token_required
def get_content(content_id):
    """Get content by ID"""
    try:
        content_model = Content()
        result = content_model.get_content_by_id(content_id)
        
        if not result['success']:
            return error_response(result['message'], 404)
        
        content = result['content']
        user = request.current_user
        
        # Check if user can view this content
        if user['role'] == 'User' and content['author_id'] != user['id']:
            return error_response('You do not have permission to view this content', 403)
        
        return success_response('Content retrieved successfully', content, 200)
            
    except Exception as e:
        return error_response(f'Failed to get content: {str(e)}', 500)


@content_bp.route('/', methods=['POST'])
@token_required
@permission_required('content.create')
def create_content():
    """Create new content"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['title', 'body', 'category_id']
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)
        
        title = data['title'].strip()
        excerpt = data.get('excerpt', '').strip()
        body = data['body'].strip()
        category_id = int(data['category_id'])
        featured_image = data.get('featured_image')
        author_id = request.current_user['id']
        
        # Auto-generate excerpt if not provided
        if not excerpt:
            excerpt = body[:200] + '...' if len(body) > 200 else body
        
        content = Content()
        result = content.create_content(title, excerpt, body, category_id, author_id, featured_image)
        
        if result['success']:
            return success_response('Content created successfully', {'content_id': result['content_id']}, 201)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to create content: {str(e)}', 500)


@content_bp.route('/<int:content_id>', methods=['PUT'])
@token_required
def update_content(content_id):
    """Update content"""
    try:
        data = request.get_json()
        
        # Check if content exists and user owns it
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Only author or admin can update
        if content['author_id'] != user['id'] and user['role'] not in ['Staff Jashumas', 'Kasubbag Jashumas']:
            return error_response('You do not have permission to update this content', 403)
        
        # Validate required fields
        required_fields = ['title', 'body', 'category_id']
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)
        
        title = data['title'].strip()
        excerpt = data.get('excerpt', '').strip()
        body = data['body'].strip()
        category_id = int(data['category_id'])
        featured_image = data.get('featured_image')
        
        # Auto-generate excerpt if not provided
        if not excerpt:
            excerpt = body[:200] + '...' if len(body) > 200 else body
        
        reset_status = content['author_id'] == user['id'] and content['status'] != 'draft'
        result = content_model.update_content(
            content_id,
            title,
            excerpt,
            body,
            category_id,
            featured_image,
            reset_status=reset_status,
        )
        
        if result['success']:
            return success_response('Content updated successfully', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to update content: {str(e)}', 500)


@content_bp.route('/<int:content_id>', methods=['DELETE'])
@token_required
def delete_content(content_id):
    """Delete content"""
    try:
        # Check if content exists and user owns it
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Only author or Kasubbag can delete
        if content['author_id'] != user['id'] and user['role'] != 'Kasubbag Jashumas':
            return error_response('You do not have permission to delete this content', 403)
        
        result = content_model.delete_content(content_id)
        
        if result['success']:
            return success_response('Content deleted successfully', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to delete content: {str(e)}', 500)


@content_bp.route('/<int:content_id>/submit', methods=['POST'])
@token_required
def submit_content(content_id):
    """Submit content for review (draft -> pending)"""
    try:
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Only author can submit
        if content['author_id'] != user['id']:
            return error_response('You do not have permission to submit this content', 403)
        
        # Check if already submitted
        if content['status'] != 'draft':
            return error_response('Content has already been submitted', 400)
        
        result = content_model.change_status(content_id, 'pending', user['id'], user['role'])
        
        if result['success']:
            return success_response('Content submitted for review', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to submit content: {str(e)}', 500)


@content_bp.route('/<int:content_id>/approve', methods=['POST'])
@token_required
@permission_required('content.approve')
def approve_content(content_id):
    """Approve content (pending -> approved)"""
    try:
        data = request.get_json()
        notes = data.get('notes', '')
        
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Check status
        if content['status'] not in ['pending', 'approved']:
            return error_response('Content cannot be approved at this stage', 400)
        
        result = content_model.change_status(content_id, 'approved', user['id'], user['role'], notes)
        
        if result['success']:
            return success_response('Content approved', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to approve content: {str(e)}', 500)


@content_bp.route('/<int:content_id>/publish', methods=['POST'])
@token_required
@permission_required('content.publish')
def publish_content(content_id):
    """Publish content (approved -> published)"""
    try:
        data = request.get_json()
        notes = data.get('notes', '')
        
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Check status
        if content['status'] != 'approved':
            return error_response('Content is not approved yet', 400)

        # Ensure both Staff and Kasubbag have approved
        approvals_result = content_model.get_approved_roles(content_id)
        if not approvals_result['success']:
            return error_response(approvals_result['message'], 500)

        required_roles = {'Staff Jashumas', 'Kasubbag Jashumas'}
        approved_roles = set(approvals_result['roles'])
        missing_roles = required_roles - approved_roles

        if missing_roles:
            return error_response(
                'Content must be accepted by Staff Jashumas and Kasubbag Jashumas before publishing',
                400
            )
        
        result = content_model.change_status(content_id, 'published', user['id'], user['role'], notes)
        
        if result['success']:
            return success_response('Content published', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to publish content: {str(e)}', 500)


@content_bp.route('/<int:content_id>/reject', methods=['POST'])
@token_required
@permission_required('content.approve')
def reject_content(content_id):
    """Reject content"""
    try:
        data = request.get_json()
        notes = data.get('notes', '')
        
        if not notes:
            return error_response('Rejection notes are required', 400)
        
        content_model = Content()
        check_result = content_model.get_content_by_id(content_id)
        
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        content = check_result['content']
        user = request.current_user
        
        # Check status
        if content['status'] not in ['pending', 'approved']:
            return error_response('Content cannot be rejected at this stage', 400)
        
        result = content_model.change_status(content_id, 'rejected', user['id'], user['role'], notes)
        
        if result['success']:
            return success_response('Content rejected', None, 200)
        else:
            return error_response(result['message'], 400)
            
    except Exception as e:
        return error_response(f'Failed to reject content: {str(e)}', 500)


@content_bp.route('/<int:content_id>/history', methods=['GET'])
@token_required
def get_content_history(content_id):
    """Get approval history for content"""
    try:
        content_model = Content()
        
        # Check if content exists
        check_result = content_model.get_content_by_id(content_id)
        if not check_result['success']:
            return error_response('Content not found', 404)
        
        result = content_model.get_approval_history(content_id)
        
        if result['success']:
            return success_response('History retrieved successfully', result['history'], 200)
        else:
            return error_response(result['message'], 500)
            
    except Exception as e:
        return error_response(f'Failed to get history: {str(e)}', 500)
