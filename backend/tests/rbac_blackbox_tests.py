# File: backend/tests/rbac_blackbox_tests.py

from __future__ import annotations

import base64
import json
import os
import time
import uuid
from datetime import datetime
from pathlib import Path

import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "backend" / ".env", override=False)
load_dotenv(ROOT / ".env", override=False)

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:5000/api").rstrip("/")

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})

def api_url(path: str) -> str:
    return f"{API_BASE_URL}/{path.lstrip('/')}"

def safe_json(resp: requests.Response) -> dict:
    try:
        return resp.json()
    except Exception:
        return {}

def auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}

def api_request(method: str, path: str, token: str | None = None, payload: dict | None = None):
    headers = {}
    if token:
        headers.update(auth_headers(token))
    return session.request(method, api_url(path), json=payload, headers=headers)

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
            "full_name": "RBAC Test User",
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

def login_user(username: str, password: str) -> str:
    resp = api_request("POST", "/auth/login", payload={"username": username, "password": password})
    if resp.status_code != 200:
        raise AssertionError(f"Login failed: {resp.status_code} {safe_json(resp) or resp.text}")
    data = safe_json(resp)
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    if not token:
        raise AssertionError("access_token missing in login response")
    return token

def get_roles(token: str) -> dict:
    resp = api_request("GET", "/users/roles", token=token)
    if resp.status_code != 200:
        raise AssertionError(f"Get roles failed: {resp.status_code} {safe_json(resp) or resp.text}")
    data = safe_json(resp).get("data", {})
    roles = data.get("roles", [])
    return {r["role_name"]: int(r["id"]) for r in roles}

def create_category(token: str, name_prefix: str) -> int:
    payload = {
        "name": f"{name_prefix} {int(time.time())}",
        "description": "RBAC test category",
        "icon": "article",
        "color": "#1976D2",
    }
    resp = api_request("POST", "/categories/", token=token, payload=payload)
    data = safe_json(resp)
    if resp.status_code != 201:
        raise AssertionError(f"Create category failed: {resp.status_code} {data or resp.text}")
    return int(data.get("data", {}).get("category_id"))

def create_content(token: str, category_id: int) -> int:
    payload = {
        "title": f"RBAC Content {int(time.time())}",
        "excerpt": "RBAC test excerpt",
        "body": "RBAC test body content",
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

def create_cooperation(token: str) -> int:
    payload = {
        "institution_name": "Institut Contoh",
        "contact_name": "Kontak Test",
        "email": "kontak@example.com",
        "phone": "08123456789",
        "purpose": "RBAC test",
        "event_date": datetime.now().strftime("%Y-%m-%d"),
        "document_name": "dokumen.txt",
        "document_mime": "text/plain",
        "document_base64": base64.b64encode(b"test").decode("utf-8"),
    }
    resp = api_request("POST", "/cooperations/", token=token, payload=payload)
    data = safe_json(resp)
    if resp.status_code != 201:
        raise AssertionError(f"Create cooperation failed: {resp.status_code} {data or resp.text}")
    return int(data.get("data", {}).get("cooperation_id"))

def run_test(name: str, method: str, path: str, token: str | None, expected, payload=None):
    resp = api_request(method, path, token=token, payload=payload)
    ok = resp.status_code in expected if isinstance(expected, (list, tuple, set)) else resp.status_code == expected
    status = "PASS" if ok else "FAIL"
    print(f"[{status}] {name} -> {resp.status_code} (expected {expected})")
    if not ok:
        print(f"  Response: {safe_json(resp) or resp.text}")
    return ok, resp

def main() -> int:
    # 1) Bootstrap: create a base user, login, fetch roles
    base_user, _e, base_pass = register_user(None, "rbac_base")
    base_token = login_user(base_user, base_pass)
    roles = get_roles(base_token)

    for required in ("User", "Staff Jashumas", "Kasubbag Jashumas"):
        if required not in roles:
            raise AssertionError(f"Role '{required}' tidak ditemukan dari /users/roles")

    # 2) Create users per role
    user_u, _e1, user_p = register_user(roles["User"], "rbac_user")
    staff_u, _e2, staff_p = register_user(roles["Staff Jashumas"], "rbac_staff")
    kasub_u, _e3, kasub_p = register_user(roles["Kasubbag Jashumas"], "rbac_kasub")

    user_token = login_user(user_u, user_p)
    staff_token = login_user(staff_u, staff_p)
    kasub_token = login_user(kasub_u, kasub_p)

    results = []

    # 3) Category tests
    results.append(run_test("User create category (should 403)", "POST", "/categories/", user_token, 403, {
        "name": f"RBAC Cat User {int(time.time())}",
        "description": "Should be forbidden",
        "icon": "article",
        "color": "#1976D2",
    }))

    ok, resp = run_test("Staff create category (should 201)", "POST", "/categories/", staff_token, 201, {
        "name": f"RBAC Cat Staff {int(time.time())}",
        "description": "RBAC category",
        "icon": "article",
        "color": "#1976D2",
    })
    results.append((ok, resp))
    category_id = None
    if ok:
        category_id = int(safe_json(resp).get("data", {}).get("category_id"))

    if category_id:
        results.append(run_test("User update category (should 403)", "PUT", f"/categories/{category_id}", user_token, 403, {
            "name": f"RBAC Cat Updated {int(time.time())}",
            "description": "Update attempt",
            "icon": "article",
            "color": "#1976D2",
        }))
        results.append(run_test("Staff update category (should 200)", "PUT", f"/categories/{category_id}", staff_token, 200, {
            "name": f"RBAC Cat Updated {int(time.time())}",
            "description": "Update by staff",
            "icon": "article",
            "color": "#1976D2",
        }))
        results.append(run_test("Staff delete category (should 403)", "DELETE", f"/categories/{category_id}", staff_token, 403))
        results.append(run_test("Kasub delete category (should 200)", "DELETE", f"/categories/{category_id}", kasub_token, 200))
    else:
        print("[SKIP] Category update/delete tests (category_id not available)")

    # 4) Content tests
    if category_id is None:
        # Try to proceed with another category by Kasub (fallback)
        try:
            category_id = create_category(kasub_token, "RBAC Cat Fallback")
        except Exception:
            print("[SKIP] Content tests (no category_id available)")
            category_id = None

    content_id = None
    if category_id:
        content_id = create_content(user_token, category_id)
        submit_content(user_token, content_id)

        results.append(run_test("User approve content (should 403)", "POST", f"/contents/{content_id}/approve", user_token, 403, {"notes": "User try"}))
        results.append(run_test("Staff approve content (should 200)", "POST", f"/contents/{content_id}/approve", staff_token, 200, {"notes": "Approved by staff"}))
        results.append(run_test("Kasub approve content (should 200)", "POST", f"/contents/{content_id}/approve", kasub_token, 200, {"notes": "Approved by kasub"}))

        results.append(run_test("User publish content (should 403)", "POST", f"/contents/{content_id}/publish", user_token, 403, {"notes": "User publish"}))
        results.append(run_test("Staff publish content (should 403)", "POST", f"/contents/{content_id}/publish", staff_token, 403, {"notes": "Staff publish"}))
        results.append(run_test("Kasub publish content (should 200)", "POST", f"/contents/{content_id}/publish", kasub_token, 200, {"notes": "Kasub publish"}))
    else:
        print("[SKIP] Content tests (no category_id)")

    # 5) Cooperation tests
    coop_id = create_cooperation(user_token)
    results.append(run_test("User verify coop (should 403)", "POST", f"/cooperations/{coop_id}/verify", user_token, 403, {}))
    results.append(run_test("Staff verify coop (should 200)", "POST", f"/cooperations/{coop_id}/verify", staff_token, 200, {}))
    results.append(run_test("User approve coop (should 403)", "POST", f"/cooperations/{coop_id}/approve", user_token, 403, {}))
    results.append(run_test("Kasub approve coop (should 200)", "POST", f"/cooperations/{coop_id}/approve", kasub_token, 200, {}))

    # 6) User management tests
    results.append(run_test("User list users (should 403)", "GET", "/users/", user_token, 403))
    results.append(run_test("Staff list users (should 200)", "GET", "/users/", staff_token, 200))
    results.append(run_test("Kasub list users (should 200)", "GET", "/users/", kasub_token, 200))

    results.append(run_test("Staff create user (should 403)", "POST", "/users/", staff_token, 403, {
        "username": f"rbac_staff_create_{uuid.uuid4().hex[:6]}",
        "email": f"rbac_staff_create_{uuid.uuid4().hex[:6]}@example.com",
        "password": "TestPass123!",
        "full_name": "RBAC Created",
        "role_id": roles["User"],
    }))
    results.append(run_test("Kasub create user (should 201)", "POST", "/users/", kasub_token, 201, {
        "username": f"rbac_kasub_create_{uuid.uuid4().hex[:6]}",
        "email": f"rbac_kasub_create_{uuid.uuid4().hex[:6]}@example.com",
        "password": "TestPass123!",
        "full_name": "RBAC Created",
        "role_id": roles["User"],
    }))

    passed = sum(1 for ok, _ in results if ok)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed")
    return 0 if passed == total else 1

if __name__ == "__main__":
    raise SystemExit(main())
