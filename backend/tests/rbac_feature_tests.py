# RBAC & feature smoke tests
# File: backend/tests/rbac_feature_tests.py

from __future__ import annotations

import os
import sys
import time
import uuid
from pathlib import Path

import pymysql
import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "backend" / ".env", override=False)
load_dotenv(ROOT / ".env", override=False)

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:5000/api").rstrip("/")

VALID_USERNAME = os.getenv("TEST_USERNAME", "rara")
VALID_PASSWORD = os.getenv("TEST_PASSWORD", "@Nr1042002yafi")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "sistem_humas_poltek")

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})

created_users: list[str] = []
created_categories: list[int] = []
created_contents: list[int] = []


def api_url(path: str) -> str:
    return f"{API_BASE_URL}/{path.lstrip('/')}"


def safe_json(resp: requests.Response) -> dict:
    try:
        return resp.json()
    except Exception:
        return {}


def api_post(path: str, payload: dict, headers: dict | None = None) -> requests.Response:
    return session.post(api_url(path), json=payload, headers=headers or {})


def api_get(path: str, headers: dict | None = None) -> requests.Response:
    return session.get(api_url(path), headers=headers or {})


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def login_api(username: str, password: str) -> tuple[int, dict]:
    resp = api_post("/auth/login", {"username": username, "password": password})
    return resp.status_code, safe_json(resp)


def get_access_token(username: str, password: str) -> str:
    status, data = login_api(username, password)
    assert status == 200, f"Login failed ({status}): {data}"
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    assert token, "access_token missing in login response"
    return token


def db_connect():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def db_fetchall(query: str, params: tuple = ()) -> list[dict]:
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return list(cur.fetchall())
    finally:
        conn.close()


def db_fetchone(query: str, params: tuple = ()) -> dict | None:
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchone()
    finally:
        conn.close()


def table_exists(table_name: str) -> bool:
    row = db_fetchone(
        """
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = %s AND table_name = %s
        LIMIT 1
        """,
        (DB_NAME, table_name),
    )
    return row is not None


def get_roles() -> list[dict]:
    return db_fetchall("SELECT id, role_name FROM roles")


def get_role_id_by_name(role_name: str) -> int | None:
    rows = db_fetchall("SELECT id, role_name FROM roles")
    for row in rows:
        if row["role_name"].lower() == role_name.lower():
            return int(row["id"])
    return None


def get_roles_with_permission(permission_name: str) -> list[int]:
    rows = db_fetchall(
        """
        SELECT DISTINCT rp.role_id
        FROM role_permissions rp
        JOIN permissions p ON rp.permission_id = p.id
        WHERE p.permission_name = %s
        """,
        (permission_name,),
    )
    return [int(r["role_id"]) for r in rows]


def get_any_category_id() -> int | None:
    if not table_exists("content_categories"):
        return None
    row = db_fetchone("SELECT id FROM content_categories ORDER BY id ASC LIMIT 1")
    return int(row["id"]) if row else None


def register_user(role_id: int, prefix: str) -> tuple[str, str, str]:
    for _ in range(5):
        suffix = f"{int(time.time())}_{uuid.uuid4().hex[:4]}"
        username = f"{prefix}_{suffix}".lower()
        email = f"{username}@example.com"
        password = "TestPass123!"

        payload = {
            "username": username,
            "email": email,
            "password": password,
            "full_name": "Test User",
            "role_id": role_id,
        }

        resp = api_post("/auth/register", payload)
        if resp.status_code == 201:
            created_users.append(username)
            return username, email, password

        data = safe_json(resp)
        if resp.status_code == 409:
            time.sleep(1)
            continue

        raise AssertionError(f"Register failed: {resp.status_code} {data or resp.text}")

    raise AssertionError("Failed to register unique user after retries")


def cleanup():
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            for content_id in created_contents:
                cur.execute("DELETE FROM contents WHERE id = %s", (content_id,))
            if table_exists("content_categories"):
                for category_id in created_categories:
                    cur.execute("DELETE FROM content_categories WHERE id = %s", (category_id,))
            for username in created_users:
                cur.execute("SELECT id FROM users WHERE username = %s", (username,))
                row = cur.fetchone()
                if not row:
                    continue
                user_id = row["id"]
                cur.execute("DELETE FROM sessions WHERE user_id = %s", (user_id,))
                cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
    finally:
        conn.close()


# --- Tests ---

def test_smoke_core_features():
    token = get_access_token(VALID_USERNAME, VALID_PASSWORD)

    # Profile
    resp = api_get("/auth/profile", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Profile expected 200, got {resp.status_code}: {data}"

    # Categories list
    resp = api_get("/categories/", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Categories expected 200, got {resp.status_code}: {data}"

    # Contents list
    resp = api_get("/contents/", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Contents expected 200, got {resp.status_code}: {data}"


def test_rbac_users_list_forbidden_for_low_role():
    roles = get_roles()
    assert roles, "Roles table empty"

    allowed_role_ids = set()
    staff_id = get_role_id_by_name("Staff Jashumas")
    kasubbag_id = get_role_id_by_name("Kasubbag Jashumas")
    if staff_id:
        allowed_role_ids.add(staff_id)
    if kasubbag_id:
        allowed_role_ids.add(kasubbag_id)

    low_role = None
    for role in roles:
        if int(role["id"]) not in allowed_role_ids:
            low_role = role
            break

    assert low_role is not None, "No low-privilege role found"

    username, _email, password = register_user(int(low_role["id"]), "rbac_low")
    token = get_access_token(username, password)

    resp = api_get("/users/", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 403, f"Expected 403, got {resp.status_code}: {data}"


def test_rbac_users_list_allowed_for_staff_or_kasubbag():
    role_id = get_role_id_by_name("Staff Jashumas") or get_role_id_by_name("Kasubbag Jashumas")
    if role_id is None:
        raise SkipTest("Staff/Kasubbag role not found")

    username, _email, password = register_user(int(role_id), "rbac_staff")
    token = get_access_token(username, password)

    resp = api_get("/users/", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {data}"


def test_permission_category_create():
    if not table_exists("content_categories"):
        raise SkipTest("Table content_categories tidak ditemukan. Jalankan migrasi content management.")
    role_ids = get_roles_with_permission("category.create")
    if not role_ids:
        raise SkipTest("No role has permission category.create")

    username, _email, password = register_user(role_ids[0], "perm_cat")
    token = get_access_token(username, password)

    payload = {
        "name": f"Test Category {int(time.time())}",
        "description": "Category created by test",
        "icon": "article",
        "color": "#1976D2",
    }
    resp = api_post("/categories/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Expected 201, got {resp.status_code}: {data}"

    category_id = data.get("data", {}).get("category_id") or data.get("category_id")
    if category_id:
        created_categories.append(int(category_id))


def test_permission_content_crud():
    if not table_exists("content_categories"):
        raise SkipTest("Table content_categories tidak ditemukan. Jalankan migrasi content management.")
    role_ids = get_roles_with_permission("content.create")
    if not role_ids:
        raise SkipTest("No role has permission content.create")

    username, _email, password = register_user(role_ids[0], "perm_content")
    token = get_access_token(username, password)

    category_id = get_any_category_id()
    if category_id is None:
        # Try to create category if allowed
        role_cat = get_roles_with_permission("category.create")
        if role_cat:
            user2, _e2, p2 = register_user(role_cat[0], "perm_content_cat")
            token2 = get_access_token(user2, p2)
            payload = {
                "name": f"Auto Category {int(time.time())}",
                "description": "Auto category for content test",
                "icon": "article",
                "color": "#1976D2",
            }
            resp = api_post("/categories/", payload, headers=auth_headers(token2))
            data = safe_json(resp)
            assert resp.status_code == 201, f"Create category expected 201, got {resp.status_code}: {data}"
            category_id = data.get("data", {}).get("category_id") or data.get("category_id")
            if category_id:
                created_categories.append(int(category_id))
        else:
            raise SkipTest("No category available and cannot create category")

    payload = {
        "title": f"Test Content {int(time.time())}",
        "excerpt": "Test excerpt",
        "body": "Test body",
        "category_id": int(category_id),
    }
    resp = api_post("/contents/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Create content expected 201, got {resp.status_code}: {data}"

    content_id = data.get("data", {}).get("content_id") or data.get("content_id")
    assert content_id, "content_id missing after create"
    created_contents.append(int(content_id))

    # Update content (author should be allowed)
    update_payload = {
        "title": f"Updated Content {int(time.time())}",
        "excerpt": "Updated excerpt",
        "body": "Updated body",
        "category_id": int(category_id),
    }
    # Content update uses PUT in backend.
    resp = session.put(api_url(f"/contents/{content_id}"), json=update_payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Update content expected 200, got {resp.status_code}: {data}"

    # Delete content (author should be allowed)
    resp = session.delete(api_url(f"/contents/{content_id}"), headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Delete content expected 200, got {resp.status_code}: {data}"


def test_content_access_control():
    if not table_exists("content_categories"):
        raise SkipTest("Table content_categories tidak ditemukan. Jalankan migrasi content management.")
    # Create content with a role that can create content
    role_ids = get_roles_with_permission("content.create")
    if not role_ids:
        raise SkipTest("No role has permission content.create")

    author_user, _email, password = register_user(role_ids[0], "author")
    author_token = get_access_token(author_user, password)

    category_id = get_any_category_id()
    if category_id is None:
        raise SkipTest("No category available for content access test")

    payload = {
        "title": f"Access Test Content {int(time.time())}",
        "excerpt": "Access control test",
        "body": "Access control test body",
        "category_id": int(category_id),
    }
    resp = api_post("/contents/", payload, headers=auth_headers(author_token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Create content expected 201, got {resp.status_code}: {data}"

    content_id = data.get("data", {}).get("content_id") or data.get("content_id")
    assert content_id, "content_id missing after create"
    created_contents.append(int(content_id))

    # Low privilege user should be forbidden to read others' content (role == 'User')
    roles = get_roles()
    low_role = None
    for role in roles:
        if role["role_name"].lower() == "user":
            low_role = role
            break
    if low_role is None:
        raise SkipTest("Role 'User' not found for access control test")

    low_user, _e2, p2 = register_user(int(low_role["id"]), "viewer")
    low_token = get_access_token(low_user, p2)

    resp = api_get(f"/contents/{content_id}", headers=auth_headers(low_token))
    data = safe_json(resp)
    assert resp.status_code == 403, f"Expected 403, got {resp.status_code}: {data}"


class SkipTest(Exception):
    pass


def run_test(name: str, fn):
    try:
        fn()
        print(f"[PASS] {name}")
        return True
    except SkipTest as e:
        print(f"[SKIP] {name}: {e}")
        return True
    except AssertionError as e:
        print(f"[FAIL] {name}: {e}")
        return False
    except Exception as e:
        print(f"[ERROR] {name}: {e}")
        return False


def main() -> int:
    results = []
    results.append(run_test("RBAC/Feature: smoke core", test_smoke_core_features))
    results.append(run_test("RBAC: users list forbidden for low role", test_rbac_users_list_forbidden_for_low_role))
    results.append(run_test("RBAC: users list allowed for staff/kasubbag", test_rbac_users_list_allowed_for_staff_or_kasubbag))
    results.append(run_test("Permission: category.create", test_permission_category_create))
    results.append(run_test("Permission: content CRUD", test_permission_content_crud))
    results.append(run_test("RBAC: content access control", test_content_access_control))

    cleanup()

    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed (including skips)")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
