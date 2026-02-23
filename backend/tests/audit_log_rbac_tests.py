# Audit log verification for RBAC-related actions
# File: backend/tests/audit_log_rbac_tests.py

from __future__ import annotations

import base64
import json
import os
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

ACTION_USER_LOGIN = os.getenv("AUDIT_ACTION_USER_LOGIN", "USER_LOGIN")
ACTION_USER_CREATED = os.getenv("AUDIT_ACTION_USER_CREATED", "USER_CREATED")
ACTION_CONTENT_INSERT = os.getenv("AUDIT_ACTION_CONTENT_INSERT", "INSERT")
ACTION_CONTENT_UPDATE = os.getenv("AUDIT_ACTION_CONTENT_UPDATE", "UPDATE")

EXPECT_ACCESS_DENIED_LOG = os.getenv("AUDIT_EXPECT_ACCESS_DENIED", "0") == "1"

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})


class SkipTest(Exception):
    pass


def api_url(path: str) -> str:
    return f"{API_BASE_URL}/{path.lstrip('/')}"


def safe_json(resp: requests.Response) -> dict:
    try:
        return resp.json()
    except Exception:
        return {}


def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def api_request(method: str, path: str, payload: dict | None = None, token: str | None = None):
    headers = {}
    if token:
        headers.update(auth_headers(token))
    return session.request(method, api_url(path), json=payload, headers=headers)


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


def find_audit(rows: list[dict], action: str, user_id: int | None = None, record_id: int | None = None) -> dict | None:
    for row in rows:
        if action and row.get("action") != action:
            continue
        if user_id is not None and row.get("user_id") != user_id:
            continue
        if record_id is not None:
            if extract_record_id(row) != record_id:
                continue
        return row
    return None


def register_user(role_id: int | None, prefix: str) -> tuple[str, str, str]:
    for _ in range(5):
        suffix = f"{int(time.time())}_{uuid.uuid4().hex[:4]}"
        username = f"{prefix}_{suffix}".lower()
        email = f"{username}@example.com"
        password = "TestPass123!"
        payload = {
            "username": username,
            "email": email,
            "password": password,
            "full_name": "Audit Log RBAC User",
        }
        if role_id is not None:
            payload["role_id"] = role_id

        resp = api_request("POST", "/auth/register", payload=payload)
        if resp.status_code == 201:
            return username, email, password
        if resp.status_code == 409:
            time.sleep(1)
            continue
        data = safe_json(resp)
        raise AssertionError(f"Register failed: {resp.status_code} {data or resp.text}")
    raise AssertionError("Failed to register unique user after retries")


def login_user(username: str, password: str) -> tuple[str, int]:
    resp = api_request("POST", "/auth/login", payload={"username": username, "password": password})
    data = safe_json(resp)
    if resp.status_code != 200:
        raise AssertionError(f"Login failed: {resp.status_code} {data or resp.text}")
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    user_id = data.get("data", {}).get("user", {}).get("id")
    if not token or not user_id:
        raise AssertionError("Login response missing token or user id")
    return token, int(user_id)


def get_roles(token: str) -> dict:
    resp = api_request("GET", "/users/roles", token=token)
    if resp.status_code != 200:
        raise AssertionError(f"Get roles failed: {resp.status_code} {safe_json(resp) or resp.text}")
    data = safe_json(resp).get("data", {})
    roles = data.get("roles", [])
    return {r["role_name"]: int(r["id"]) for r in roles}


def get_category_id(token: str, staff_token: str | None) -> int:
    resp = api_request("GET", "/categories/", token=token)
    data = safe_json(resp)
    if resp.status_code != 200:
        raise AssertionError(f"Get categories failed: {resp.status_code} {data or resp.text}")
    categories = data.get("data", [])
    if categories:
        return int(categories[0]["id"])
    if not staff_token:
        raise SkipTest("Tidak ada kategori dan staff_token tidak tersedia")
    payload = {
        "name": f"Auto Category {int(time.time())}",
        "description": "Auto category for audit log test",
        "icon": "article",
        "color": "#1976D2",
    }
    resp = api_request("POST", "/categories/", token=staff_token, payload=payload)
    data = safe_json(resp)
    if resp.status_code != 201:
        raise AssertionError(f"Create category failed: {resp.status_code} {data or resp.text}")
    return int(data.get("data", {}).get("category_id"))


def create_content(token: str, category_id: int) -> int:
    payload = {
        "title": f"Audit Log Content {int(time.time())}",
        "excerpt": "Audit log test excerpt",
        "body": "Audit log test body content",
        "category_id": int(category_id),
    }
    resp = api_request("POST", "/contents/", token=token, payload=payload)
    data = safe_json(resp)
    if resp.status_code != 201:
        raise AssertionError(f"Create content failed: {resp.status_code} {data or resp.text}")
    return int(data.get("data", {}).get("content_id"))


def submit_content(token: str, content_id: int):
    resp = api_request("POST", f"/contents/{content_id}/submit", token=token, payload={})
    if resp.status_code != 200:
        raise AssertionError(f"Submit content failed: {resp.status_code} {safe_json(resp) or resp.text}")


def approve_content(token: str, content_id: int, notes: str):
    resp = api_request(
        "POST",
        f"/contents/{content_id}/approve",
        token=token,
        payload={"notes": notes},
    )
    if resp.status_code != 200:
        raise AssertionError(f"Approve content failed: {resp.status_code} {safe_json(resp) or resp.text}")


def create_user_by_kasub(token: str, role_id: int) -> int:
    payload = {
        "username": f"audit_user_{uuid.uuid4().hex[:6]}",
        "email": f"audit_user_{uuid.uuid4().hex[:6]}@example.com",
        "password": "TestPass123!",
        "full_name": "Audit Created User",
        "role_id": role_id,
    }
    resp = api_request("POST", "/users/", token=token, payload=payload)
    data = safe_json(resp)
    if resp.status_code != 201:
        raise AssertionError(f"Create user failed: {resp.status_code} {data or resp.text}")
    return int(data.get("data", {}).get("user_id"))


def describe_logs(rows: list[dict]) -> str:
    parts = []
    for row in rows:
        parts.append(f"id={row.get('id')} action={row.get('action')} user_id={row.get('user_id')}")
    return "; ".join(parts) if parts else "(no logs)"


def run_test(name: str, fn):
    try:
        print(f"[RUN] {name}", flush=True)
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


def main() -> int:
    results = []

    base_user, _e, base_pass = register_user(None, "audit_base")
    base_token, _base_id = login_user(base_user, base_pass)
    roles = get_roles(base_token)

    for required in ("User", "Staff Jashumas", "Kasubbag Jashumas"):
        if required not in roles:
            raise AssertionError(f"Role '{required}' tidak ditemukan dari /users/roles")

    user_u, _e1, user_p = register_user(roles["User"], "audit_user")
    staff_u, _e2, staff_p = register_user(roles["Staff Jashumas"], "audit_staff")
    kasub_u, _e3, kasub_p = register_user(roles["Kasubbag Jashumas"], "audit_kasub")

    def tc_login_audit():
        last_id = get_last_audit_id()
        _token, user_id = login_user(user_u, user_p)
        rows = fetch_audit_after(last_id)
        row = find_audit(rows, action=ACTION_USER_LOGIN, user_id=user_id)
        assert row, f"Audit log {ACTION_USER_LOGIN} tidak ditemukan. Logs: {describe_logs(rows)}"

    def tc_user_created_audit():
        kasub_token, kasub_id = login_user(kasub_u, kasub_p)
        last_id = get_last_audit_id()
        created_user_id = create_user_by_kasub(kasub_token, roles["User"])
        rows = fetch_audit_after(last_id)
        row = find_audit(rows, action=ACTION_USER_CREATED, user_id=kasub_id)
        assert row, f"Audit log {ACTION_USER_CREATED} tidak ditemukan. Logs: {describe_logs(rows)}"
        details = parse_details(row.get("details"))
        if details.get("created_user_id") is not None:
            assert int(details["created_user_id"]) == created_user_id, "created_user_id mismatch"

    def tc_content_insert_update_audit():
        user_token, user_id = login_user(user_u, user_p)
        staff_token, _staff_id = login_user(staff_u, staff_p)
        category_id = get_category_id(user_token, staff_token)

        last_id = get_last_audit_id()
        content_id = create_content(user_token, category_id)
        rows = fetch_audit_after(last_id)
        row = find_audit(rows, action=ACTION_CONTENT_INSERT, user_id=user_id, record_id=content_id)
        assert row, f"Audit log {ACTION_CONTENT_INSERT} tidak ditemukan. Logs: {describe_logs(rows)}"

        submit_content(user_token, content_id)
        last_id = get_last_audit_id()
        approve_content(staff_token, content_id, "Approve for audit log test")
        rows = fetch_audit_after(last_id)
        # Note: trigger uses author_id as user_id for UPDATE on contents
        row = find_audit(rows, action=ACTION_CONTENT_UPDATE, user_id=user_id, record_id=content_id)
        assert row, f"Audit log {ACTION_CONTENT_UPDATE} tidak ditemukan. Logs: {describe_logs(rows)}"

    def tc_access_denied_audit():
        if not EXPECT_ACCESS_DENIED_LOG:
            raise SkipTest("Access denied logging tidak diaktifkan (AUDIT_EXPECT_ACCESS_DENIED=0)")
        user_token, user_id = login_user(user_u, user_p)
        last_id = get_last_audit_id()
        resp = api_request("GET", "/users/", token=user_token)
        assert resp.status_code == 403, f"Expected 403, got {resp.status_code}"
        rows = fetch_audit_after(last_id)
        row = find_audit(rows, action="ACCESS_DENIED", user_id=user_id)
        assert row, f"Audit log ACCESS_DENIED tidak ditemukan. Logs: {describe_logs(rows)}"

    results.append(run_test("TC-AL01 Login berhasil dicatat", tc_login_audit))
    results.append(run_test("TC-AL02 Create user dicatat", tc_user_created_audit))
    results.append(run_test("TC-AL03 Content insert/update dicatat", tc_content_insert_update_audit))
    results.append(run_test("TC-AL04 Access denied dicatat (opsional)", tc_access_denied_audit))

    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed (including skips)")
    return 0 if passed == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
