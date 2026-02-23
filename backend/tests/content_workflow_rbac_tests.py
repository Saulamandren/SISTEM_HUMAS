# RBAC & content workflow tests
# File: backend/tests/content_workflow_rbac_tests.py

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

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "sistem_humas_poltek")

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})

created_users: list[str] = []
created_contents: list[int] = []
created_categories: list[int] = []
DEFAULT_CATEGORY_ID: int | None = None
CURRENT_TEST: str | None = None


class SkipTest(Exception):
    pass


def log_step(message: str):
    if CURRENT_TEST:
        print(f"  [STEP] {message}", flush=True)
    else:
        print(f"[STEP] {message}", flush=True)


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


def db_fetchone(query: str, params: tuple = ()) -> dict | None:
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchone()
    finally:
        conn.close()


def db_fetchall(query: str, params: tuple = ()) -> list[dict]:
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return list(cur.fetchall())
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


def require_tables(*tables: str):
    missing = [t for t in tables if not table_exists(t)]
    if missing:
        raise SkipTest(
            "Tabel tidak ditemukan: "
            + ", ".join(missing)
            + ". Jalankan migrasi content management."
        )


def get_role_id_by_name(role_name: str) -> int | None:
    row = db_fetchone("SELECT id FROM roles WHERE role_name = %s", (role_name,))
    return int(row["id"]) if row else None


def require_role(role_name: str) -> int:
    role_id = get_role_id_by_name(role_name)
    if not role_id:
        raise SkipTest(f"Role '{role_name}' tidak ditemukan")
    return role_id


def role_has_permission(role_id: int, permission_name: str) -> bool:
    row = db_fetchone(
        """
        SELECT 1
        FROM role_permissions rp
        JOIN permissions p ON rp.permission_id = p.id
        WHERE rp.role_id = %s AND p.permission_name = %s
        LIMIT 1
        """,
        (role_id, permission_name),
    )
    return row is not None


def login_api(username: str, password: str) -> tuple[int, dict]:
    resp = api_post("/auth/login", {"username": username, "password": password})
    return resp.status_code, safe_json(resp)


def get_access_token(username: str, password: str) -> str:
    log_step(f"Login sebagai {username}")
    status, data = login_api(username, password)
    assert status == 200, f"Login failed ({status}): {data}"
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    assert token, "access_token missing in login response"
    return token


def register_user(role_id: int, prefix: str) -> tuple[str, str, str]:
    for _ in range(5):
        suffix = f"{int(time.time())}_{uuid.uuid4().hex[:4]}"
        username = f"{prefix}_{suffix}".lower()
        email = f"{username}@example.com"
        password = "TestPass123!"
        log_step(f"Registrasi user {username} (role_id={role_id})")
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
        if resp.status_code == 409:
            time.sleep(1)
            continue
        data = safe_json(resp)
        raise AssertionError(f"Register failed: {resp.status_code} {data or resp.text}")
    raise AssertionError("Failed to register unique user after retries")


def register_user_by_role(role_name: str, prefix: str) -> tuple[str, str, str]:
    role_id = require_role(role_name)
    return register_user(role_id, prefix)


def get_any_category_id() -> int | None:
    row = db_fetchone("SELECT id FROM content_categories ORDER BY id ASC LIMIT 1")
    return int(row["id"]) if row else None


def create_category(token: str) -> int:
    log_step("Membuat kategori (auto)")
    payload = {
        "name": f"Auto Category {int(time.time())}",
        "description": "Auto category for workflow test",
        "icon": "article",
        "color": "#1976D2",
    }
    resp = api_post("/categories/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Create category expected 201, got {resp.status_code}: {data}"
    category_id = data.get("data", {}).get("category_id") or data.get("category_id")
    assert category_id, "category_id missing after create"
    created_categories.append(int(category_id))
    return int(category_id)


def ensure_category() -> int:
    global DEFAULT_CATEGORY_ID
    if DEFAULT_CATEGORY_ID:
        return DEFAULT_CATEGORY_ID

    require_tables("content_categories")
    category_id = get_any_category_id()
    if category_id:
        log_step(f"Gunakan kategori existing id={category_id}")
        DEFAULT_CATEGORY_ID = category_id
        return category_id

    # Create category using a role that has category.create
    role_id = get_role_id_by_name("Staff Jashumas") or get_role_id_by_name("Kasubbag Jashumas")
    if role_id is None or not role_has_permission(role_id, "category.create"):
        rows = db_fetchall(
            """
            SELECT DISTINCT rp.role_id
            FROM role_permissions rp
            JOIN permissions p ON rp.permission_id = p.id
            WHERE p.permission_name = %s
            """,
            ("category.create",),
        )
        if not rows:
            raise SkipTest("Tidak ada role dengan permission category.create")
        role_id = int(rows[0]["role_id"])

    username, _email, password = register_user(role_id, "cat_setup")
    token = get_access_token(username, password)
    category_id = create_category(token)
    DEFAULT_CATEGORY_ID = category_id
    return category_id


def create_content(token: str, category_id: int, title_prefix: str) -> int:
    log_step(f"Membuat konten ({title_prefix}) di kategori {category_id}")
    payload = {
        "title": f"{title_prefix} {int(time.time())}",
        "excerpt": "Test excerpt",
        "body": "Test body content",
        "category_id": int(category_id),
    }
    resp = api_post("/contents/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Create content expected 201, got {resp.status_code}: {data}"
    content_id = data.get("data", {}).get("content_id") or data.get("content_id")
    assert content_id, "content_id missing after create"
    created_contents.append(int(content_id))
    return int(content_id)


def get_content(token: str, content_id: int) -> dict:
    log_step(f"Ambil konten id={content_id}")
    resp = api_get(f"/contents/{content_id}", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Get content expected 200, got {resp.status_code}: {data}"
    return data.get("data", {})


def submit_content(token: str, content_id: int):
    log_step(f"Submit konten id={content_id} (draft -> pending)")
    resp = api_post(f"/contents/{content_id}/submit", {}, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Submit expected 200, got {resp.status_code}: {data}"


def approve_content(token: str, content_id: int, notes: str):
    log_step(f"Approve konten id={content_id}: {notes}")
    resp = api_post(
        f"/contents/{content_id}/approve",
        {"notes": notes},
        headers=auth_headers(token),
    )
    data = safe_json(resp)
    assert resp.status_code == 200, f"Approve expected 200, got {resp.status_code}: {data}"


def reject_content(token: str, content_id: int, notes: str):
    log_step(f"Reject konten id={content_id}: {notes}")
    resp = api_post(
        f"/contents/{content_id}/reject",
        {"notes": notes},
        headers=auth_headers(token),
    )
    data = safe_json(resp)
    assert resp.status_code == 200, f"Reject expected 200, got {resp.status_code}: {data}"


def publish_content(token: str, content_id: int, notes: str):
    log_step(f"Publish konten id={content_id}: {notes}")
    resp = api_post(
        f"/contents/{content_id}/publish",
        {"notes": notes},
        headers=auth_headers(token),
    )
    data = safe_json(resp)
    assert resp.status_code == 200, f"Publish expected 200, got {resp.status_code}: {data}"


def get_history(token: str, content_id: int) -> list[dict]:
    log_step(f"Ambil history konten id={content_id}")
    resp = api_get(f"/contents/{content_id}/history", headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"History expected 200, got {resp.status_code}: {data}"
    return data.get("data", [])


def cleanup():
    if not (table_exists("contents") and table_exists("content_categories")):
        return
    log_step("Cleanup data uji")
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            for content_id in created_contents:
                cur.execute("DELETE FROM contents WHERE id = %s", (content_id,))
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


# --- Test scenarios ---

def test_role_users_create_until_pending():
    require_tables("content_categories", "contents", "content_approvals")

    user_role_id = require_role("User")
    if not role_has_permission(user_role_id, "content.create"):
        raise AssertionError("Role User tidak memiliki permission content.create")

    username, _email, password = register_user(user_role_id, "user_pending")
    token = get_access_token(username, password)

    category_id = ensure_category()
    content_id = create_content(token, category_id, "User Pending Content")

    content = get_content(token, content_id)
    assert content.get("status") == "draft", f"Status awal bukan draft: {content.get('status')}"

    submit_content(token, content_id)
    content = get_content(token, content_id)
    assert content.get("status") == "pending", f"Status setelah submit bukan pending: {content.get('status')}"


def test_user_verified_by_staff_and_kasubbag():
    require_tables("content_categories", "contents", "content_approvals")

    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    kasub_role_id = require_role("Kasubbag Jashumas")

    if not role_has_permission(staff_role_id, "content.approve"):
        raise AssertionError("Role Staff Jashumas tidak memiliki permission content.approve")
    if not role_has_permission(kasub_role_id, "content.approve"):
        raise AssertionError("Role Kasubbag Jashumas tidak memiliki permission content.approve")

    user, _e1, p1 = register_user(user_role_id, "user_verify")
    staff, _e2, p2 = register_user(staff_role_id, "staff_verify")
    kasub, _e3, p3 = register_user(kasub_role_id, "kasub_verify")

    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)
    kasub_token = get_access_token(kasub, p3)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "User Verify Content")
    submit_content(user_token, content_id)

    approve_content(staff_token, content_id, "Approved by staff")
    approve_content(kasub_token, content_id, "Approved by kasubbag")

    content = get_content(user_token, content_id)
    assert content.get("status") == "approved", f"Status akhir bukan approved: {content.get('status')}"

    history = get_history(user_token, content_id)
    approved_roles = {h.get("approver_role") for h in history if h.get("action") == "approve"}
    assert "Staff Jashumas" in approved_roles, "Approval staff tidak ditemukan di history"
    assert "Kasubbag Jashumas" in approved_roles, "Approval kasubbag tidak ditemukan di history"


def test_kasubbag_can_publish():
    require_tables("content_categories", "contents", "content_approvals")

    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    kasub_role_id = require_role("Kasubbag Jashumas")

    if not role_has_permission(staff_role_id, "content.approve"):
        raise AssertionError("Role Staff Jashumas tidak memiliki permission content.approve")
    if not role_has_permission(kasub_role_id, "content.approve"):
        raise AssertionError("Role Kasubbag Jashumas tidak memiliki permission content.approve")
    if not role_has_permission(kasub_role_id, "content.publish"):
        raise AssertionError("Role Kasubbag Jashumas tidak memiliki permission content.publish")

    user, _e1, p1 = register_user(user_role_id, "user_publish")
    staff, _e2, p2 = register_user(staff_role_id, "staff_publish")
    kasub, _e3, p3 = register_user(kasub_role_id, "kasub_publish")

    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)
    kasub_token = get_access_token(kasub, p3)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "User Publish Content")
    submit_content(user_token, content_id)

    approve_content(staff_token, content_id, "Approved by staff")
    approve_content(kasub_token, content_id, "Approved by kasubbag")
    publish_content(kasub_token, content_id, "Published by kasubbag")

    content = get_content(user_token, content_id)
    assert content.get("status") == "published", f"Status akhir bukan published: {content.get('status')}"


def test_staff_can_reject_with_comment():
    require_tables("content_categories", "contents", "content_approvals")

    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    if not role_has_permission(staff_role_id, "content.approve"):
        raise AssertionError("Role Staff Jashumas tidak memiliki permission content.approve")

    user, _e1, p1 = register_user(user_role_id, "user_reject_staff")
    staff, _e2, p2 = register_user(staff_role_id, "staff_reject")

    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "User Reject Staff")
    submit_content(user_token, content_id)

    reject_note = "Perlu revisi judul"
    reject_content(staff_token, content_id, reject_note)

    content = get_content(user_token, content_id)
    assert content.get("status") == "rejected", f"Status akhir bukan rejected: {content.get('status')}"

    history = get_history(user_token, content_id)
    notes = [h.get("notes", "") for h in history if h.get("action") == "reject"]
    assert any(reject_note in n for n in notes), "Catatan reject staff tidak ditemukan"


def test_kasubbag_can_reject():
    require_tables("content_categories", "contents", "content_approvals")

    user_role_id = require_role("User")
    kasub_role_id = require_role("Kasubbag Jashumas")
    if not role_has_permission(kasub_role_id, "content.approve"):
        raise AssertionError("Role Kasubbag Jashumas tidak memiliki permission content.approve")

    user, _e1, p1 = register_user(user_role_id, "user_reject_kasub")
    kasub, _e2, p2 = register_user(kasub_role_id, "kasub_reject")

    user_token = get_access_token(user, p1)
    kasub_token = get_access_token(kasub, p2)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "User Reject Kasub")
    submit_content(user_token, content_id)

    reject_note = "Isi belum sesuai standar"
    reject_content(kasub_token, content_id, reject_note)

    content = get_content(user_token, content_id)
    assert content.get("status") == "rejected", f"Status akhir bukan rejected: {content.get('status')}"

    history = get_history(user_token, content_id)
    notes = [h.get("notes", "") for h in history if h.get("action") == "reject"]
    assert any(reject_note in n for n in notes), "Catatan reject kasubbag tidak ditemukan"


def test_users_can_register():
    role_id = require_role("User")
    _username, _email, _password = register_user(role_id, "user_register")


def test_staff_can_create_content():
    require_tables("content_categories", "contents", "content_approvals")

    staff_role_id = require_role("Staff Jashumas")
    if not role_has_permission(staff_role_id, "content.create"):
        raise AssertionError("Role Staff Jashumas tidak memiliki permission content.create")

    staff, _e1, p1 = register_user(staff_role_id, "staff_create")
    staff_token = get_access_token(staff, p1)

    category_id = ensure_category()
    content_id = create_content(staff_token, category_id, "Staff Create Content")

    content = get_content(staff_token, content_id)
    assert content.get("status") == "draft", f"Status awal bukan draft: {content.get('status')}"


def run_test(name: str, fn):
    try:
        print(f"[RUN] {name}", flush=True)
        global CURRENT_TEST
        CURRENT_TEST = name
        fn()
        print(f"[PASS] {name}", flush=True)
        return True
    except SkipTest as e:
        print(f"[SKIP] {name}: {e}", flush=True)
        return True
    except AssertionError as e:
        print(f"[FAIL] {name}: {e}", flush=True)
        return False
    except Exception as e:
        print(f"[ERROR] {name}: {e}", flush=True)
        return False
    finally:
        CURRENT_TEST = None


def main() -> int:
    results = []
    results.append(run_test("1. User create content -> pending", test_role_users_create_until_pending))
    results.append(run_test("2. User verified by staff & kasubbag", test_user_verified_by_staff_and_kasubbag))
    results.append(run_test("3. Kasubbag can publish", test_kasubbag_can_publish))
    results.append(run_test("4. Staff can reject with comment", test_staff_can_reject_with_comment))
    results.append(run_test("5. Kasubbag can reject", test_kasubbag_can_reject))
    results.append(run_test("6. User can register", test_users_can_register))
    results.append(run_test("7. Staff can create content", test_staff_can_create_content))

    cleanup()

    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed (including skips)")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
