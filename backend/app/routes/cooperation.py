import base64
from datetime import datetime
from flask import Blueprint, request
from app.models.cooperation import Cooperation
from app.utils.decorators import token_required, permission_required
from app.utils.response import success_response, error_response

cooperation_bp = Blueprint('cooperation', __name__)


@cooperation_bp.route('/', methods=['GET'])
@token_required
def get_cooperations():
    """Get cooperation applications (own for User, all for Staff/Kasubbag)"""
    try:
        status = request.args.get('status')
        user = request.current_user

        created_by = None
        if user['role'] == 'User':
            created_by = user['id']

        coop = Cooperation()
        result = coop.get_cooperations(created_by=created_by, status=status)

        if result['success']:
            return success_response(
                'Cooperations retrieved successfully',
                result['cooperations'],
                200,
            )
        return error_response(result['message'], 500)
    except Exception as e:
        return error_response(f'Failed to get cooperations: {str(e)}', 500)


@cooperation_bp.route('/', methods=['POST'])
@token_required
@permission_required('submit_coop')
def create_cooperation():
    """Create new cooperation application"""
    try:
        data = request.get_json()
        required_fields = [
            'institution_name',
            'contact_name',
            'email',
            'phone',
            'purpose',
            'event_date',
            'document_name',
            'document_base64',
        ]
        for field in required_fields:
            if field not in data or not data[field]:
                return error_response(f'{field} is required', 400)

        try:
            event_date = datetime.strptime(data['event_date'], '%Y-%m-%d').date()
        except ValueError:
            return error_response('event_date must be YYYY-MM-DD', 400)

        try:
            document_data = base64.b64decode(data['document_base64'])
        except Exception:
            return error_response('document_base64 is invalid', 400)

        coop = Cooperation()
        result = coop.create_cooperation(
            institution_name=data['institution_name'].strip(),
            contact_name=data['contact_name'].strip(),
            email=data['email'].strip(),
            phone=data['phone'].strip(),
            purpose=data['purpose'].strip(),
            event_date=event_date,
            document_name=data['document_name'].strip(),
            document_mime=data.get('document_mime'),
            document_data=document_data,
            created_by=request.current_user['id'],
        )

        if result['success']:
            return success_response(
                'Cooperation created successfully',
                {'cooperation_id': result['cooperation_id']},
                201,
            )
        return error_response(result['message'], 400)
    except Exception as e:
        return error_response(f'Failed to create cooperation: {str(e)}', 500)


@cooperation_bp.route('/<int:cooperation_id>/verify', methods=['POST'])
@token_required
@permission_required('verify_coop')
def verify_cooperation(cooperation_id):
    """Verify cooperation (pending -> verified)"""
    try:
        coop = Cooperation()
        check = coop.get_cooperation_by_id(cooperation_id)
        if not check['success']:
            return error_response(check['message'], 404)

        item = check['cooperation']
        if item['status'] != 'pending':
            return error_response('Cooperation is not pending', 400)

        result = coop.change_status(cooperation_id, 'verified')
        if result['success']:
            return success_response('Cooperation verified', None, 200)
        return error_response(result['message'], 400)
    except Exception as e:
        return error_response(f'Failed to verify cooperation: {str(e)}', 500)


@cooperation_bp.route('/<int:cooperation_id>/approve', methods=['POST'])
@token_required
@permission_required('approve_coop')
def approve_cooperation(cooperation_id):
    """Approve cooperation (verified -> approved)"""
    try:
        coop = Cooperation()
        check = coop.get_cooperation_by_id(cooperation_id)
        if not check['success']:
            return error_response(check['message'], 404)

        item = check['cooperation']
        if item['status'] != 'verified':
            return error_response('Cooperation must be verified first', 400)

        result = coop.change_status(cooperation_id, 'approved')
        if result['success']:
            return success_response('Cooperation approved', None, 200)
        return error_response(result['message'], 400)
    except Exception as e:
        return error_response(f'Failed to approve cooperation: {str(e)}', 500)


@cooperation_bp.route('/<int:cooperation_id>/reject', methods=['POST'])
@token_required
def reject_cooperation(cooperation_id):
    """Reject cooperation (pending/verified -> rejected)"""
    try:
        user = request.current_user
        if user['role'] not in ['Staff Jashumas', 'Kasubbag Jashumas']:
            return error_response('You do not have permission to reject', 403)

        coop = Cooperation()
        check = coop.get_cooperation_by_id(cooperation_id)
        if not check['success']:
            return error_response(check['message'], 404)

        item = check['cooperation']
        if item['status'] not in ['pending', 'verified']:
            return error_response('Cooperation cannot be rejected', 400)

        result = coop.change_status(cooperation_id, 'rejected')
        if result['success']:
            return success_response('Cooperation rejected', None, 200)
        return error_response(result['message'], 400)
    except Exception as e:
        return error_response(f'Failed to reject cooperation: {str(e)}', 500)


@cooperation_bp.route('/<int:cooperation_id>/document', methods=['GET'])
@token_required
def get_cooperation_document(cooperation_id):
    """Get cooperation document (base64)"""
    try:
        user = request.current_user

        coop = Cooperation()
        result = coop.get_document_by_id(cooperation_id)
        if not result['success']:
            return error_response(result['message'], 404)

        doc = result['document']

        # Access control: staff/kasubbag or owner
        if user['role'] not in ['Staff Jashumas', 'Kasubbag Jashumas'] and user['id'] != doc['created_by']:
            return error_response('You do not have permission to view this document', 403)

        document_data = doc['document_data']
        if document_data is None:
            return error_response('Document not found', 404)

        return success_response(
            'Document retrieved successfully',
            {
                'document_name': doc['document_name'],
                'document_mime': doc.get('document_mime'),
                'document_base64': base64.b64encode(document_data).decode('utf-8'),
            },
            200,
        )
    except Exception as e:
        return error_response(f'Failed to get document: {str(e)}', 500)
