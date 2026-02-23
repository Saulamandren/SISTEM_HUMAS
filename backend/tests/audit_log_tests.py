# Audit log test script
# File: backend/tests/audit_log_tests.py

from __future__ import annotations

import base64
import json
import os
import sys
import time
import uuid
from datetime import datetime
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

ACTION_LOGIN_SUCCESS = os.getenv("AUDIT_ACTION_LOGIN_SUCCESS", "LOGIN")
ACTION_LOGIN_FAILED = os.getenv("AUDIT_ACTION_LOGIN_FAILED", "LOGIN_FAILED")
ACTION_CREATE_CONTENT = os.getenv("AUDIT_ACTION_CREATE_CONTENT", "CREATE_CONTENT")
ACTION_VERIFY_CONTENT = os.getenv("AUDIT_ACTION_VERIFY_CONTENT", "VERIFY_CONTENT")
ACTION_APPROVE_CONTENT = os.getenv("AUDIT_ACTION_APPROVE_CONTENT", "APPROVE_CONTENT")
ACTION_SUBMIT_COOP = os.getenv("AUDIT_ACTION_SUBMIT_COOP", "SUBMIT_COOP")
ACTION_APPROVE_COOP = os.getenv("AUDIT_ACTION_APPROVE_COOP", "APPROVE_COOP")
ACTION_ACCESS_DENIED = os.getenv("AUDIT_ACTION_ACCESS_DENIED", "ACCESS_DENIED")

ACCESS_DENIED_ENDPOINT = os.getenv("AUDIT_ACCESS_DENIED_ENDPOINT", "/api/users/")

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})

created_users: list[str] = []
created_contents: list[int] = []
created_categories: list[int] = []
created_coops: list[int] = []

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
        raise SkipTest("Tabel tidak ditemukan: " + ", ".join(missing))


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


def require_permission(role_id: int, permission_name: str):
    if not role_has_permission(role_id, permission_name):
        raise SkipTest(f"Role tidak memiliki permission: {permission_name}")


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


def get_user_id(username: str) -> int:
    row = db_fetchone("SELECT id FROM users WHERE username = %s", (username,))
    if not row:
        raise AssertionError("User ID not found in DB")
    return int(row["id"])


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


def get_last_audit_id() -> int:
    row = db_fetchone("SELECT MAX(id) AS max_id FROM audit_logs")
    return int(row["max_id"] or 0)


def fetch_audit_after(last_id: int) -> list[dict]:
    return db_fetchall(
        "SELECT * FROM audit_logs WHERE id > %s ORDER BY id ASC",
        (last_id,),
    )


def parse_details(details) -> dict:
    if details is None:
        return {}
    if isinstance(details, dict):
        return details
    if isinstance(details, (bytes, bytearray)):
        details = details.decode("utf-8", errors="ignore")
    if isinstance(details, str):
        try:
            return json.loads(details)
        except Exception:
            return {"_raw": details}
    return {"_raw": str(details)}


def extract_record_id(row: dict) -> int | None:
    record_id = row.get("record_id")
    if record_id is not None:
        try:
            return int(record_id)
        except Exception:
            pass
    details = parse_details(row.get("details"))
    if "record_id" in details:
        try:
            return int(details["record_id"])
        except Exception:
            return None
    if "new_values" in details and isinstance(details["new_values"], dict):
        if "record_id" in details["new_values"]:
            try:
                return int(details["new_values"]["record_id"])
            except Exception:
                return None
    return None


def details_contains(details: dict, needle: str) -> bool:
    if not needle:
        return True
    for key in ("endpoint", "path", "url"):
        if details.get(key) == needle:
            return True
    raw = details.get("_raw")
    if raw and needle in raw:
        return True
    return False


def details_contains_role(details: dict, role_name: str) -> bool:
    for key in ("role", "user_role"):
        if details.get(key) == role_name:
            return True
    raw = details.get("_raw")
    if raw and role_name in raw:
        return True
    return False


def describe_logs(rows: list[dict]) -> str:
    parts = []
    for row in rows:
        parts.append(
            f"id={row.get('id')} action={row.get('action')} user_id={row.get('user_id')}"
        )
    return "; ".join(parts) if parts else "(no logs)"


def find_audit(
    rows: list[dict],
    action: str,
    user_id: int | None = None,
    resource_id: int | None = None,
    endpoint: str | None = None,
    role_name: str | None = None,
) -> dict | None:
    for row in rows:
        if action and row.get("action") != action:
            continue
        if user_id is not None and row.get("user_id") != user_id:
            continue
        if resource_id is not None:
            record_id = extract_record_id(row)
            if record_id != resource_id:
                continue
        if endpoint or role_name:
            details = parse_details(row.get("details"))
            if endpoint and not details_contains(details, endpoint):
                continue
            if role_name and not details_contains_role(details, role_name):
                continue
        return row
    return None


def ensure_category() -> int:
    require_tables("content_categories")
    row = db_fetchone("SELECT id FROM content_categories ORDER BY id ASC LIMIT 1")
    if row:
        return int(row["id"])

    # create category with any role that has category.create
    role_row = db_fetchone(
        """
        SELECT DISTINCT rp.role_id
        FROM role_permissions rp
        JOIN permissions p ON rp.permission_id = p.id
        WHERE p.permission_name = %s
        LIMIT 1
        """,
        ("category.create",),
    )
    if not role_row:
        raise SkipTest("Tidak ada role dengan permission category.create")

    role_id = int(role_row["role_id"])
    username, _email, password = register_user(role_id, "cat_setup")
    token = get_access_token(username, password)
    log_step("Membuat kategori (auto)")
    payload = {
        "name": f"Auto Category {int(time.time())}",
        "description": "Auto category for audit test",
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


def create_cooperation(token: str) -> int:
    log_step("Submit pengajuan kerja sama")
    payload = {
        "institution_name": "Institut Contoh",
        "contact_name": "Kontak Test",
        "email": "kontak@example.com",
        "phone": "08123456789",
        "purpose": "Uji audit log",
        "event_date": datetime.now().strftime("%Y-%m-%d"),
        "document_name": "dokumen.txt",
        "document_mime": "text/plain",
        "document_base64": base64.b64encode(b"test").decode("utf-8"),
    }
    resp = api_post("/cooperations/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 201, f"Create cooperation expected 201, got {resp.status_code}: {data}"
    coop_id = data.get("data", {}).get("cooperation_id") or data.get("cooperation_id")
    assert coop_id, "cooperation_id missing after create"
    created_coops.append(int(coop_id))
    return int(coop_id)


def verify_cooperation(token: str, coop_id: int):
    log_step(f"Verify pengajuan kerja sama id={coop_id}")
    resp = api_post(f"/cooperations/{coop_id}/verify", {}, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Verify cooperation expected 200, got {resp.status_code}: {data}"


def approve_cooperation(token: str, coop_id: int):
    log_step(f"Approve pengajuan kerja sama id={coop_id}")
    resp = api_post(f"/cooperations/{coop_id}/approve", {}, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 200, f"Approve cooperation expected 200, got {resp.status_code}: {data}"


def cleanup():
    if not table_exists("audit_logs"):
        return
    log_step("Cleanup data uji")
    conn = db_connect()
    try:
        with conn.cursor() as cur:
            for content_id in created_contents:
                cur.execute("DELETE FROM contents WHERE id = %s", (content_id,))
            for category_id in created_categories:
                cur.execute("DELETE FROM content_categories WHERE id = %s", (category_id,))
            for coop_id in created_coops:
                cur.execute("DELETE FROM cooperations WHERE id = %s", (coop_id,))
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


# --- Test cases ---

def test_tc_a01_login_success():
    require_tables("audit_logs", "users", "roles")
    user_role_id = require_role("User")
    username, _email, password = register_user(user_role_id, "audit_login_ok")
    user_id = get_user_id(username)

    last_id = get_last_audit_id()
    log_step("Login sukses untuk audit")
    status, _ = login_api(username, password)
    assert status == 200, f"Login expected 200, got {status}"

    rows = fetch_audit_after(last_id)
    row = find_audit(rows, action=ACTION_LOGIN_SUCCESS, user_id=user_id)
    assert row, f"Audit log {ACTION_LOGIN_SUCCESS} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a02_login_failed():
    require_tables("audit_logs", "users", "roles")
    user_role_id = require_role("User")
    username, _email, password = register_user(user_role_id, "audit_login_fail")

    last_id = get_last_audit_id()
    log_step("Login gagal (password salah)")
    status, _ = login_api(username, password + "_wrong")
    assert status == 401, f"Login failed expected 401, got {status}"

    rows = fetch_audit_after(last_id)
    row = find_audit(rows, action=ACTION_LOGIN_FAILED)
    assert row, f"Audit log {ACTION_LOGIN_FAILED} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a03_create_draft_content():
    require_tables("audit_logs", "content_categories", "contents")
    user_role_id = require_role("User")
    require_permission(user_role_id, "content.create")

    username, _email, password = register_user(user_role_id, "audit_content_create")
    user_id = get_user_id(username)
    token = get_access_token(username, password)

    category_id = ensure_category()
    last_id = get_last_audit_id()
    content_id = create_content(token, category_id, "Audit Draft")

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_CREATE_CONTENT,
        user_id=user_id,
        resource_id=content_id,
    )
    assert row, f"Audit log {ACTION_CREATE_CONTENT} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a04_verify_content():
    require_tables("audit_logs", "content_categories", "contents", "content_approvals")
    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    require_permission(user_role_id, "content.create")
    require_permission(staff_role_id, "content.approve")

    user, _e1, p1 = register_user(user_role_id, "audit_verify_user")
    staff, _e2, p2 = register_user(staff_role_id, "audit_verify_staff")

    user_id = get_user_id(user)
    staff_id = get_user_id(staff)

    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "Audit Verify")
    submit_content(user_token, content_id)

    last_id = get_last_audit_id()
    approve_content(staff_token, content_id, "Verified by staff")

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_VERIFY_CONTENT,
        user_id=staff_id,
        resource_id=content_id,
    )
    assert row, f"Audit log {ACTION_VERIFY_CONTENT} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a05_approve_content():
    require_tables("audit_logs", "content_categories", "contents", "content_approvals")
    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    kasub_role_id = require_role("Kasubbag Jashumas")
    require_permission(user_role_id, "content.create")
    require_permission(staff_role_id, "content.approve")
    require_permission(kasub_role_id, "content.approve")

    user, _e1, p1 = register_user(user_role_id, "audit_approve_user")
    staff, _e2, p2 = register_user(staff_role_id, "audit_approve_staff")
    kasub, _e3, p3 = register_user(kasub_role_id, "audit_approve_kasub")

    kasub_id = get_user_id(kasub)
    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)
    kasub_token = get_access_token(kasub, p3)

    category_id = ensure_category()
    content_id = create_content(user_token, category_id, "Audit Approve")
    submit_content(user_token, content_id)
    approve_content(staff_token, content_id, "Approved by staff")

    last_id = get_last_audit_id()
    approve_content(kasub_token, content_id, "Approved by kasubbag")

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_APPROVE_CONTENT,
        user_id=kasub_id,
        resource_id=content_id,
    )
    assert row, f"Audit log {ACTION_APPROVE_CONTENT} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a06_submit_coop():
    require_tables("audit_logs", "cooperations")
    user_role_id = require_role("User")
    require_permission(user_role_id, "submit_coop")

    user, _e1, p1 = register_user(user_role_id, "audit_coop_submit")
    user_id = get_user_id(user)
    token = get_access_token(user, p1)

    last_id = get_last_audit_id()
    coop_id = create_cooperation(token)

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_SUBMIT_COOP,
        user_id=user_id,
        resource_id=coop_id,
    )
    assert row, f"Audit log {ACTION_SUBMIT_COOP} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a07_approve_coop():
    require_tables("audit_logs", "cooperations")
    user_role_id = require_role("User")
    staff_role_id = require_role("Staff Jashumas")
    kasub_role_id = require_role("Kasubbag Jashumas")
    require_permission(user_role_id, "submit_coop")
    require_permission(staff_role_id, "verify_coop")
    require_permission(kasub_role_id, "approve_coop")

    user, _e1, p1 = register_user(user_role_id, "audit_coop_user")
    staff, _e2, p2 = register_user(staff_role_id, "audit_coop_staff")
    kasub, _e3, p3 = register_user(kasub_role_id, "audit_coop_kasub")

    kasub_id = get_user_id(kasub)
    user_token = get_access_token(user, p1)
    staff_token = get_access_token(staff, p2)
    kasub_token = get_access_token(kasub, p3)

    coop_id = create_cooperation(user_token)
    verify_cooperation(staff_token, coop_id)

    last_id = get_last_audit_id()
    approve_cooperation(kasub_token, coop_id)

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_APPROVE_COOP,
        user_id=kasub_id,
        resource_id=coop_id,
    )
    assert row, f"Audit log {ACTION_APPROVE_COOP} tidak ditemukan. Logs: {describe_logs(rows)}"


def test_tc_a08_access_denied():
    require_tables("audit_logs", "users", "roles")
    user_role_id = require_role("User")

    user, _e1, p1 = register_user(user_role_id, "audit_access_denied")
    user_id = get_user_id(user)
    token = get_access_token(user, p1)

    last_id = get_last_audit_id()
    log_step("Akses endpoint terlarang untuk memicu 403")
    resp = api_get("/users/", headers=auth_headers(token))
    assert resp.status_code == 403, f"Expected 403, got {resp.status_code}"

    rows = fetch_audit_after(last_id)
    row = find_audit(
        rows,
        action=ACTION_ACCESS_DENIED,
        user_id=user_id,
        endpoint=ACCESS_DENIED_ENDPOINT,
        role_name="User",
    )
    assert row, f"Audit log {ACTION_ACCESS_DENIED} tidak ditemukan. Logs: {describe_logs(rows)}"


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
    results.append(run_test("TC-A01 Login berhasil", test_tc_a01_login_success))
    results.append(run_test("TC-A02 Login gagal", test_tc_a02_login_failed))
    results.append(run_test("TC-A03 Pembuatan draft berita", test_tc_a03_create_draft_content))
    results.append(run_test("TC-A04 Verifikasi konten", test_tc_a04_verify_content))
    results.append(run_test("TC-A05 Approve konten", test_tc_a05_approve_content))
    results.append(run_test("TC-A06 Submit kerja sama", test_tc_a06_submit_coop))
    results.append(run_test("TC-A07 Approve kerja sama", test_tc_a07_approve_coop))
    results.append(run_test("TC-A08 Access denied 403", test_tc_a08_access_denied))

    cleanup()

    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed (including skips)", flush=True)
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
