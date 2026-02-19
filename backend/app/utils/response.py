from flask import jsonify

def success_response(message, data=None, status_code=200):
    """Standard success response"""
    response = {
        'status': 'success',
        'message': message
    }
    
    if data is not None:
        response['data'] = data
    
    return jsonify(response), status_code

def error_response(message, status_code=400, errors=None):
    """Standard error response"""
    response = {
        'status': 'error',
        'message': message
    }
    
    if errors:
        response['errors'] = errors
    
    return jsonify(response), status_code
