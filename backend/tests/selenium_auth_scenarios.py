# Selenium + API test script for 8 auth/security scenarios
# File: backend/tests/selenium_auth_scenarios.py

from __future__ import annotations

import os
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jwt
import pymysql
import requests
from dotenv import load_dotenv

# Optional Selenium (UI login) support
SELENIUM_AVAILABLE = False
try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    SELENIUM_AVAILABLE = True
except Exception:
    SELENIUM_AVAILABLE = False

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / "backend" / ".env", override=False)
load_dotenv(ROOT / ".env", override=False)

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:5000/api").rstrip("/")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:8080").rstrip("/")
FRONTEND_LOGIN_PATH = os.getenv("FRONTEND_LOGIN_PATH", "/login")

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "jwt-secret-change-this")

VALID_USERNAME = os.getenv("TEST_USERNAME", "rara")
VALID_PASSWORD = os.getenv("TEST_PASSWORD", "@Nr1042002yafi")

REGISTER_PASSWORD = os.getenv("TEST_REGISTER_PASSWORD", "TestPass123!")
REGISTER_FULLNAME = os.getenv("TEST_REGISTER_FULLNAME", "Test User")

RUN_UI = os.getenv("RUN_UI", "0") == "1"
HEADLESS = os.getenv("HEADLESS", "1") != "0"
BROWSER = os.getenv("BROWSER", "chrome").lower()

LOGIN_USERNAME_SELECTOR = os.getenv(
    "LOGIN_USERNAME_SELECTOR",
    'input[placeholder="Masukkan username atau email"]',
)
LOGIN_PASSWORD_SELECTOR = os.getenv(
    "LOGIN_PASSWORD_SELECTOR",
    'input[placeholder="Masukkan password"]',
)
LOGIN_BUTTON_XPATH = os.getenv(
    "LOGIN_BUTTON_XPATH",
    "//button[normalize-space()='Masuk' or .//span[normalize-space()='Masuk']]",
)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "sistem_humas_poltek")

session = requests.Session()
session.headers.update({"Content-Type": "application/json"})

REGISTERED_USER: tuple[str, str, str] | None = None


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


def login_api(username: str, password: str) -> requests.Response:
    return api_post("/auth/login", {"username": username, "password": password})


def get_access_token() -> str:
    resp = login_api(VALID_USERNAME, VALID_PASSWORD)
    data = safe_json(resp)
    assert resp.status_code == 200, f"Login valid expected 200, got {resp.status_code}: {data}"
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    assert token, "access_token missing in login response"
    return token


def make_expired_token(valid_token: str) -> str:
    payload = jwt.decode(valid_token, options={"verify_signature": False})
    now = datetime.now(tz=timezone.utc)
    payload["exp"] = now - timedelta(seconds=30)
    payload["iat"] = now - timedelta(seconds=60)
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm="HS256")


def tamper_token(token: str) -> str:
    parts = token.split(".")
    if len(parts) != 3:
        raise AssertionError("Invalid JWT format")
    sig = parts[2]
    if not sig:
        raise AssertionError("Empty JWT signature")
    last = sig[-1]
    new_last = "a" if last != "a" else "b"
    parts[2] = sig[:-1] + new_last
    return ".".join(parts)


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


def register_user() -> tuple[str, str, str]:
    for _ in range(5):
        suffix = f"{int(time.time())}_{uuid.uuid4().hex[:4]}"
        username = f"test.user_{suffix}".lower()
        email = f"{username}@example.com"

        payload = {
            "username": username,
            "email": email,
            "password": REGISTER_PASSWORD,
            "full_name": REGISTER_FULLNAME,
        }

        resp = api_post("/auth/register", payload)
        if resp.status_code == 201:
            return username, email, REGISTER_PASSWORD

        data = safe_json(resp)
        if resp.status_code == 409:
            time.sleep(1)
            continue

        raise AssertionError(
            f"Register failed: {resp.status_code} {data or resp.text}"
        )

    raise AssertionError("Failed to register unique user after retries")


def cleanup_user(username: str) -> None:
    try:
        conn = db_connect()
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE username = %s", (username,))
            row = cur.fetchone()
            if not row:
                return
            user_id = row["id"]
            cur.execute("DELETE FROM sessions WHERE user_id = %s", (user_id,))
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
    finally:
        try:
            conn.close()
        except Exception:
            pass


# --- Selenium UI (optional) ---

def build_driver():
    if not SELENIUM_AVAILABLE:
        raise RuntimeError("Selenium is not installed. Install with: pip install selenium")

    if BROWSER == "edge":
        options = webdriver.EdgeOptions()
        if HEADLESS:
            options.add_argument("--headless=new")
        return webdriver.Edge(options=options)

    options = webdriver.ChromeOptions()
    if HEADLESS:
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1280,900")
    return webdriver.Chrome(options=options)


def ui_login(driver, username: str, password: str, expect_success: bool):
    driver.get(f"{FRONTEND_URL}{FRONTEND_LOGIN_PATH}")
    wait = WebDriverWait(driver, 20)

    try:
        user_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, LOGIN_USERNAME_SELECTOR))
        )
        pass_input = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, LOGIN_PASSWORD_SELECTOR))
        )
    except Exception as e:
        raise AssertionError(
            "UI elements not found. Set LOGIN_USERNAME_SELECTOR/LOGIN_PASSWORD_SELECTOR "
            "env vars to match your DOM (Flutter web can differ)."
        ) from e

    user_input.clear()
    user_input.send_keys(username)
    pass_input.clear()
    pass_input.send_keys(password)

    try:
        login_btn = wait.until(
            EC.element_to_be_clickable((By.XPATH, LOGIN_BUTTON_XPATH))
        )
        login_btn.click()
    except Exception as e:
        raise AssertionError(
            "Login button not found. Set LOGIN_BUTTON_XPATH env var to match your DOM."
        ) from e

    if expect_success:
        wait.until(EC.presence_of_element_located((By.XPATH, "//*[contains(text(),'Login berhasil')]")))
    else:
        wait.until(
            EC.presence_of_element_located(
                (By.XPATH, "//*[contains(text(),'Login gagal') or contains(text(),'salah')]")
            )
        )


def run_ui_login_tests():
    if not RUN_UI:
        return

    driver = build_driver()
    try:
        ui_login(driver, VALID_USERNAME, VALID_PASSWORD, expect_success=True)
        ui_login(driver, VALID_USERNAME, VALID_PASSWORD + "_wrong", expect_success=False)
    finally:
        driver.quit()


# --- Scenario tests (API/DB) ---

def test_login_valid():
    resp = login_api(VALID_USERNAME, VALID_PASSWORD)
    data = safe_json(resp)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {data}"
    token = data.get("data", {}).get("tokens", {}).get("access_token")
    assert token, "JWT access_token not found"


def test_login_wrong_password():
    resp = login_api(VALID_USERNAME, VALID_PASSWORD + "_wrong")
    data = safe_json(resp)
    assert resp.status_code == 401, f"Expected 401, got {resp.status_code}: {data}"


def test_request_without_token():
    resp = api_get("/auth/profile")
    data = safe_json(resp)
    assert resp.status_code == 401, f"Expected 401, got {resp.status_code}: {data}"


def test_expired_token():
    token = get_access_token()
    expired = make_expired_token(token)
    resp = api_get("/auth/profile", headers=auth_headers(expired))
    data = safe_json(resp)
    assert resp.status_code == 401, f"Expected 401, got {resp.status_code}: {data}"


def test_tampered_token():
    token = get_access_token()
    tampered = tamper_token(token)
    resp = api_get("/auth/profile", headers=auth_headers(tampered))
    data = safe_json(resp)
    assert resp.status_code == 401, f"Expected 401, got {resp.status_code}: {data}"


def test_role_mismatch():
    token = get_access_token()
    payload = {
        "username": "temp.user",
        "email": "temp.user@example.com",
        "password": "TempPass123!",
        "full_name": "Temp User",
        "role_id": 1,
    }
    resp = api_post("/users/", payload, headers=auth_headers(token))
    data = safe_json(resp)
    assert resp.status_code == 403, f"Expected 403, got {resp.status_code}: {data}"


def test_password_hash_argon2():
    global REGISTERED_USER
    REGISTERED_USER = register_user()
    username, _email, plain_password = REGISTERED_USER

    conn = db_connect()
    with conn.cursor() as cur:
        cur.execute("SELECT password_hash FROM users WHERE username = %s", (username,))
        row = cur.fetchone()
    conn.close()

    assert row, "User not found in DB after registration"
    password_hash = row["password_hash"]
    assert password_hash != plain_password, "Password hash should not be plaintext"
    assert password_hash.startswith("$argon2id$"), "Password hash is not Argon2id"


def test_verify_hash_login():
    global REGISTERED_USER
    if REGISTERED_USER is None:
        REGISTERED_USER = register_user()

    username, _email, password = REGISTERED_USER
    resp = login_api(username, password)
    data = safe_json(resp)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {data}"


def run_test(name: str, fn):
    try:
        fn()
        print(f"[PASS] {name}")
        return True
    except AssertionError as e:
        print(f"[FAIL] {name}: {e}")
        return False
    except Exception as e:
        print(f"[ERROR] {name}: {e}")
        return False


def main() -> int:
    if RUN_UI:
        if not SELENIUM_AVAILABLE:
            print("[ERROR] RUN_UI=1 but Selenium not installed. pip install selenium")
            return 1
        run_ui_login_tests()

    results = []
    results.append(run_test("1. Login dengan kredensial valid", test_login_valid))
    results.append(run_test("2. Login dengan kata sandi salah", test_login_wrong_password))
    results.append(run_test("3. Request tanpa token", test_request_without_token))
    results.append(run_test("4. Token kedaluwarsa", test_expired_token))
    results.append(run_test("5. Token dimanipulasi", test_tampered_token))
    results.append(run_test("6. Akses role tidak sesuai", test_role_mismatch))
    results.append(run_test("7. Penyimpanan password hash Argon2", test_password_hash_argon2))
    results.append(run_test("8. Verifikasi hash saat login", test_verify_hash_login))

    if REGISTERED_USER is not None:
        cleanup_user(REGISTERED_USER[0])

    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"\nSummary: {passed}/{total} passed")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(main())
