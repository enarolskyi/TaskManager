"""API tests. Кожен тест — на окремій тимчасовій БД."""
import importlib
import os

import pytest
from fastapi.testclient import TestClient

VALID_USER = {
    "full_name": "Ed Test",
    "phone": "+380671234567",
    "email": "ed@test.com",
    "password": "Test1234",
}


@pytest.fixture
def client(tmp_path):
    os.environ["TASKMANAGER_DB"] = str(tmp_path / "test.db")
    import main
    importlib.reload(main)
    return TestClient(main.app)


@pytest.fixture
def auth_headers(client):
    token = client.post("/auth/register", json=VALID_USER).json()["token"]
    return {"Authorization": f"Bearer {token}"}


# ---------- Auth ----------

def test_register_success(client):
    r = client.post("/auth/register", json=VALID_USER)
    assert r.status_code == 201
    body = r.json()
    assert body["token"]
    assert body["user"]["email"] == "ed@test.com"
    assert "password" not in body["user"]


def test_register_duplicate_email(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/register", json={**VALID_USER, "email": "ED@test.com"})
    assert r.status_code == 409


@pytest.mark.parametrize("field,value", [
    ("email", "not-an-email"),
    ("phone", "123"),
    ("password", "short1A"),
    ("password", "nouppercase1"),
    ("password", "NoNumbersHere"),
    ("full_name", " "),
])
def test_register_validation(client, field, value):
    r = client.post("/auth/register", json={**VALID_USER, field: value})
    assert r.status_code == 422


def test_login_success(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/login", json={"email": "ed@test.com", "password": "Test1234"})
    assert r.status_code == 200
    assert r.json()["token"]


def test_login_wrong_password(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/login", json={"email": "ed@test.com", "password": "Wrong1234"})
    assert r.status_code == 401


def test_me_requires_token(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer fake"}).status_code == 401


def test_logout_invalidates_token(client, auth_headers):
    assert client.post("/auth/logout", headers=auth_headers).status_code == 204
    assert client.get("/me", headers=auth_headers).status_code == 401


# ---------- Tasks ----------

NEW_TASK = {"title": "Water the flowers", "priority": "low", "tag": "Home", "due_date": "2026-11-15"}


def test_create_and_list_tasks(client, auth_headers):
    r = client.post("/tasks", json=NEW_TASK, headers=auth_headers)
    assert r.status_code == 201
    assert r.json()["status"] == "todo"

    tasks = client.get("/tasks", headers=auth_headers).json()
    assert len(tasks) == 1
    assert tasks[0]["title"] == "Water the flowers"


def test_create_task_empty_title(client, auth_headers):
    r = client.post("/tasks", json={**NEW_TASK, "title": "  "}, headers=auth_headers)
    assert r.status_code == 422


def test_move_task_to_done(client, auth_headers):
    task_id = client.post("/tasks", json=NEW_TASK, headers=auth_headers).json()["id"]
    r = client.patch(f"/tasks/{task_id}", json={"status": "done"}, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["status"] == "done"
    assert r.json()["title"] == "Water the flowers"

    done = client.get("/tasks?status_filter=done", headers=auth_headers).json()
    assert len(done) == 1


def test_delete_task(client, auth_headers):
    task_id = client.post("/tasks", json=NEW_TASK, headers=auth_headers).json()["id"]
    assert client.delete(f"/tasks/{task_id}", headers=auth_headers).status_code == 204
    assert client.get("/tasks", headers=auth_headers).json() == []


def test_user_cannot_see_other_users_tasks(client, auth_headers):
    task_id = client.post("/tasks", json=NEW_TASK, headers=auth_headers).json()["id"]

    other = client.post("/auth/register", json={**VALID_USER, "email": "other@test.com"}).json()
    other_headers = {"Authorization": f"Bearer {other['token']}"}

    assert client.get("/tasks", headers=other_headers).json() == []
    assert client.patch(f"/tasks/{task_id}", json={"status": "done"}, headers=other_headers).status_code == 404
    assert client.delete(f"/tasks/{task_id}", headers=other_headers).status_code == 404


# ---------- Profile ----------

def test_update_profile(client, auth_headers):
    r = client.patch("/me", json={"full_name": "Eduard", "phone": "+380991112233"}, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["full_name"] == "Eduard"
    assert r.json()["email"] == "ed@test.com"


def test_update_profile_email_taken(client, auth_headers):
    client.post("/auth/register", json={**VALID_USER, "email": "taken@test.com"})
    r = client.patch("/me", json={"email": "taken@test.com"}, headers=auth_headers)
    assert r.status_code == 409


@pytest.mark.parametrize("field,value", [("email", "bad"), ("phone", "12"), ("full_name", "A")])
def test_update_profile_validation(client, auth_headers, field, value):
    assert client.patch("/me", json={field: value}, headers=auth_headers).status_code == 422


def test_change_password(client, auth_headers):
    r = client.post("/me/password", json={"current_password": "Test1234", "new_password": "NewPass123"},
                    headers=auth_headers)
    assert r.status_code == 204
    assert client.post("/auth/login", json={"email": "ed@test.com", "password": "Test1234"}).status_code == 401
    assert client.post("/auth/login", json={"email": "ed@test.com", "password": "NewPass123"}).status_code == 200
    assert client.get("/me", headers=auth_headers).status_code == 200   # поточна сесія не зачіпається


def test_change_password_wrong_current(client, auth_headers):
    r = client.post("/me/password", json={"current_password": "Wrong1234", "new_password": "NewPass123"},
                    headers=auth_headers)
    assert r.status_code == 400


def test_change_password_logs_out_other_sessions(client, auth_headers):
    other = client.post("/auth/login", json={"email": "ed@test.com", "password": "Test1234"}).json()["token"]
    client.post("/me/password", json={"current_password": "Test1234", "new_password": "NewPass123"},
                headers=auth_headers)
    assert client.get("/me", headers={"Authorization": f"Bearer {other}"}).status_code == 401


def test_delete_account(client, auth_headers):
    client.post("/tasks", json=NEW_TASK, headers=auth_headers)
    assert client.delete("/me", headers=auth_headers).status_code == 204
    assert client.get("/me", headers=auth_headers).status_code == 401
    assert client.post("/auth/login", json={"email": "ed@test.com", "password": "Test1234"}).status_code == 401


# ---------- Settings ----------

def test_default_settings(client, auth_headers):
    r = client.get("/settings", headers=auth_headers)
    assert r.status_code == 200
    assert r.json() == {"theme": "system", "timezone": "UTC", "week_start": "monday"}


def test_update_settings(client, auth_headers):
    r = client.patch("/settings", json={"theme": "dark", "timezone": "Europe/Kyiv"}, headers=auth_headers)
    assert r.status_code == 200
    assert r.json() == {"theme": "dark", "timezone": "Europe/Kyiv", "week_start": "monday"}
    assert client.get("/settings", headers=auth_headers).json()["theme"] == "dark"


@pytest.mark.parametrize("body", [{"theme": "pink"}, {"timezone": "Mars/Base"}, {"week_start": "friday"}])
def test_update_settings_validation(client, auth_headers, body):
    assert client.patch("/settings", json=body, headers=auth_headers).status_code == 422


# ---------- Tasks by date ----------

def test_filter_tasks_by_date(client, auth_headers):
    for day in ["2026-11-14", "2026-11-15", "2026-11-15", "2026-11-20"]:
        client.post("/tasks", json={**NEW_TASK, "due_date": day}, headers=auth_headers)

    assert len(client.get("/tasks?due_date=2026-11-15", headers=auth_headers).json()) == 2
    week = client.get("/tasks?due_from=2026-11-14&due_to=2026-11-16", headers=auth_headers).json()
    assert [t["due_date"] for t in week] == ["2026-11-14", "2026-11-15", "2026-11-15"]


def test_patch_task_with_null_is_ignored(client, auth_headers):
    task_id = client.post("/tasks", json=NEW_TASK, headers=auth_headers).json()["id"]
    r = client.patch(f"/tasks/{task_id}", json={"status": None, "title": "New"}, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["status"] == "todo"
    assert r.json()["title"] == "New"
