import re
from email_validator import validate_email as email_validate, EmailNotValidError


def validate_email(email):
    """Validate email format (legacy helper)."""
    try:
        email_validate(email)
        return True
    except EmailNotValidError:
        return False


def validate_email_format(email: str) -> tuple:
    """
    Validate and normalize email address.

    Returns:
        tuple: (is_valid: bool, message: str, normalized_email: str)
    """
    if not email:
        return False, "Email harus diisi", email

    try:
        try:
            result = email_validate(email, check_deliverability=False)
        except TypeError:
            # Fallback for older email_validator versions
            result = email_validate(email)
        return True, "Email valid", result.email
    except EmailNotValidError:
        return False, "Format email tidak valid", email


def validate_username(username: str) -> tuple:
    """
    Validate username rules.

    Returns:
        tuple: (is_valid: bool, message: str)
    """
    if not username:
        return False, "Username harus diisi"

    username = username.strip()
    if len(username) < 3:
        return False, "Username minimal 3 karakter"
    if len(username) > 50:
        return False, "Username maksimal 50 karakter"
    if not re.match(r'^[a-zA-Z0-9._]+$', username):
        return False, "Username hanya boleh huruf, angka, titik, dan underscore"

    return True, "Username valid"


def validate_full_name(full_name: str) -> tuple:
    """
    Validate full name.

    Returns:
        tuple: (is_valid: bool, message: str)
    """
    if not full_name:
        return False, "Nama lengkap harus diisi"

    full_name = full_name.strip()
    if len(full_name) < 3:
        return False, "Nama lengkap minimal 3 karakter"
    if len(full_name) > 100:
        return False, "Nama lengkap maksimal 100 karakter"
    if re.search(r'\d', full_name):
        return False, "Nama lengkap tidak boleh mengandung angka"

    return True, "Nama lengkap valid"


def validate_nip(nip: str) -> tuple:
    """
    Validate NIP (18 digits).

    Returns:
        tuple: (is_valid: bool, message: str)
    """
    if not nip:
        return False, "NIP harus diisi"

    nip = nip.strip()
    if len(nip) != 18:
        return False, "NIP harus 18 digit"
    if not re.match(r'^\d+$', nip):
        return False, "NIP harus berupa angka"

    return True, "NIP valid"


def validate_role_id(role_id, valid_roles: list) -> tuple:
    """
    Validate role id is provided and exists in valid roles.

    Returns:
        tuple: (is_valid: bool, message: str)
    """
    if role_id is None:
        return False, "Role harus diisi"

    try:
        role_id_int = int(role_id)
    except (TypeError, ValueError):
        return False, "Role tidak valid"

    if role_id_int not in valid_roles:
        return False, "Role tidak valid"

    return True, "Role valid"


def validate_password(password):
    """
    Validate password strength:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"
    
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain at least one uppercase letter"
    
    if not re.search(r'[a-z]', password):
        return False, "Password must contain at least one lowercase letter"
    
    if not re.search(r'\d', password):
        return False, "Password must contain at least one digit"
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False, "Password must contain at least one special character"
    
    return True, "Password is valid"
