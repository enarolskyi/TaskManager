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
    assert r.json() == {"theme": "system", "timezone": "UTC", "week_start": "monday",
                        "daily_goal": 5, "weekly_goal": 30}


def test_update_settings(client, auth_headers):
    r = client.patch("/settings", json={"theme": "dark", "timezone": "Europe/Kyiv"}, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["theme"] == "dark"
    assert r.json()["timezone"] == "Europe/Kyiv"
    assert r.json()["week_start"] == "monday"
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


# ---------- Search / filters / sort ----------

@pytest.fixture
def sample_tasks(client, auth_headers):
    tasks = [
        {"title": "Water the flowers", "priority": "low", "tag": "Home", "due_date": "2026-11-20"},
        {"title": "Book a table", "details": "Valentine's day", "priority": "high", "tag": "Relationship", "due_date": "2026-11-15"},
        {"title": "Create workout plan", "priority": "medium", "tag": "Sport", "due_date": "2026-11-18"},
        {"title": "buy protein", "priority": "high", "tag": "Sport", "due_date": "2026-11-16"},
    ]
    for t in tasks:
        client.post("/tasks", json=t, headers=auth_headers)
    return tasks


def titles(response):
    return [t["title"] for t in response.json()]


def test_search_by_title_case_insensitive(client, auth_headers, sample_tasks):
    r = client.get("/tasks?search=WATER", headers=auth_headers)
    assert titles(r) == ["Water the flowers"]


def test_search_matches_details_and_tag(client, auth_headers, sample_tasks):
    assert titles(client.get("/tasks?search=valentine", headers=auth_headers)) == ["Book a table"]
    assert len(client.get("/tasks?search=sport", headers=auth_headers).json()) == 2


def test_filter_by_multiple_tags(client, auth_headers, sample_tasks):
    r = client.get("/tasks?tag=Home&tag=Relationship", headers=auth_headers)
    assert sorted(titles(r)) == ["Book a table", "Water the flowers"]


def test_filter_by_priority(client, auth_headers, sample_tasks):
    r = client.get("/tasks?priority=high", headers=auth_headers)
    assert {t["priority"] for t in r.json()} == {"high"}
    assert len(r.json()) == 2


def test_combined_filters(client, auth_headers, sample_tasks):
    r = client.get("/tasks?tag=Sport&priority=high", headers=auth_headers)
    assert titles(r) == ["buy protein"]


@pytest.mark.parametrize("sort,expected", [
    ("created", ["Water the flowers", "Book a table", "Create workout plan", "buy protein"]),
    ("due_date", ["Book a table", "buy protein", "Create workout plan", "Water the flowers"]),
    ("priority", ["Book a table", "buy protein", "Create workout plan", "Water the flowers"]),
    ("name", ["Book a table", "buy protein", "Create workout plan", "Water the flowers"]),
])
def test_sort(client, auth_headers, sample_tasks, sort, expected):
    assert titles(client.get(f"/tasks?sort={sort}", headers=auth_headers)) == expected


@pytest.mark.parametrize("query", ["sort=random", "priority=urgent"])
def test_invalid_filter_values(client, auth_headers, query):
    assert client.get(f"/tasks?{query}", headers=auth_headers).status_code == 422


def test_filters_respect_other_users(client, auth_headers, sample_tasks):
    other = client.post("/auth/register", json={**VALID_USER, "email": "other@test.com"}).json()
    r = client.get("/tasks?search=water", headers={"Authorization": f"Bearer {other['token']}"})
    assert r.json() == []


# ---------- Tag length ----------

def test_tag_max_length_allowed(client, auth_headers):
    r = client.post("/tasks", json={**NEW_TASK, "tag": "a" * 20}, headers=auth_headers)
    assert r.status_code == 201


def test_tag_too_long_on_create(client, auth_headers):
    r = client.post("/tasks", json={**NEW_TASK, "tag": "a" * 21}, headers=auth_headers)
    assert r.status_code == 422


def test_tag_too_long_on_update(client, auth_headers):
    task_id = client.post("/tasks", json=NEW_TASK, headers=auth_headers).json()["id"]
    r = client.patch(f"/tasks/{task_id}", json={"tag": "a" * 21}, headers=auth_headers)
    assert r.status_code == 422


# ---------- Productivity: completed_at, goals, stats ----------

import sqlite3
from datetime import date, datetime, timedelta, timezone


def complete(client, headers, task_id):
    return client.patch(f"/tasks/{task_id}", json={"status": "done"}, headers=headers)


def new_task(client, headers, **fields):
    # Дата в майбутньому, щоб задача не рахувалась простроченою
    future = (date.today() + timedelta(days=7)).isoformat()
    return client.post("/tasks", json={**NEW_TASK, "due_date": future, **fields}, headers=headers).json()["id"]


def set_completed_at(task_id, when: datetime):
    # Підміняємо дату виконання напряму в БД, щоб перевірити минулі дні
    conn = sqlite3.connect(os.environ["TASKMANAGER_DB"])
    conn.execute("UPDATE tasks SET completed_at = ? WHERE id = ?", (when.isoformat(), task_id))
    conn.commit()
    conn.close()


def test_completed_at_set_and_cleared(client, auth_headers):
    task_id = new_task(client, auth_headers)
    assert client.get("/tasks", headers=auth_headers).json()[0]["completed_at"] is None

    done = complete(client, auth_headers, task_id).json()
    assert done["completed_at"] is not None

    back = client.patch(f"/tasks/{task_id}", json={"status": "todo"}, headers=auth_headers).json()
    assert back["completed_at"] is None


def test_completed_at_not_moved_by_repeated_patch(client, auth_headers):
    task_id = new_task(client, auth_headers)
    set_completed_at(task_id, datetime.now(timezone.utc) - timedelta(days=3))
    client.patch(f"/tasks/{task_id}", json={"status": "done"}, headers=auth_headers)   # стає done
    set_completed_at(task_id, datetime(2026, 1, 1, tzinfo=timezone.utc))
    r = client.patch(f"/tasks/{task_id}", json={"status": "done", "title": "Renamed"}, headers=auth_headers)
    assert r.json()["completed_at"].startswith("2026-01-01")


def test_create_task_as_done_sets_completed_at(client, auth_headers):
    r = client.post("/tasks", json={**NEW_TASK, "status": "done"}, headers=auth_headers)
    assert r.json()["completed_at"] is not None


def test_update_goals(client, auth_headers):
    r = client.patch("/settings", json={"daily_goal": 3, "weekly_goal": 15}, headers=auth_headers)
    assert r.status_code == 200
    assert (r.json()["daily_goal"], r.json()["weekly_goal"]) == (3, 15)


@pytest.mark.parametrize("body", [{"daily_goal": 0}, {"daily_goal": 101}, {"weekly_goal": -1}])
def test_goals_validation(client, auth_headers, body):
    assert client.patch("/settings", json=body, headers=auth_headers).status_code == 422


def test_stats_requires_auth(client):
    assert client.get("/stats").status_code == 401


def test_stats_empty(client, auth_headers):
    r = client.get("/stats", headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert len(body["days"]) == 7
    assert body["days"][-1]["date"] == date.today().isoformat()
    assert body["completed_today"] == 0
    assert body["streak"] == 0


def test_stats_counts(client, auth_headers):
    t1 = new_task(client, auth_headers)
    t2 = new_task(client, auth_headers)
    new_task(client, auth_headers, status="in_progress")
    new_task(client, auth_headers, due_date=(date.today() - timedelta(days=2)).isoformat())   # прострочена
    complete(client, auth_headers, t1)
    complete(client, auth_headers, t2)

    body = client.get("/stats", headers=auth_headers).json()
    assert body["completed_today"] == 2
    assert body["days"][-1]["completed"] == 2
    assert body["total_completed"] == 2
    assert body["in_progress"] == 1
    assert body["todo"] == 1
    assert body["overdue"] == 1


def test_stats_streak(client, auth_headers):
    client.patch("/settings", json={"daily_goal": 1}, headers=auth_headers)
    now = datetime.now(timezone.utc)
    # Виконано вчора і позавчора, а 3 дні тому — пропуск
    for days_ago in (1, 2, 4):
        task_id = new_task(client, auth_headers)
        complete(client, auth_headers, task_id)
        set_completed_at(task_id, now - timedelta(days=days_ago))

    assert client.get("/stats", headers=auth_headers).json()["streak"] == 2

    # Сьогоднішня задача продовжує серію
    complete(client, auth_headers, new_task(client, auth_headers))
    assert client.get("/stats", headers=auth_headers).json()["streak"] == 3


@pytest.mark.parametrize("days", [0, 91])
def test_stats_days_validation(client, auth_headers, days):
    assert client.get(f"/stats?days={days}", headers=auth_headers).status_code == 422


def test_migration_adds_new_columns(tmp_path):
    # База старого формату (без completed_at і цілей) має оновитися при старті
    path = tmp_path / "old.db"
    conn = sqlite3.connect(path)
    conn.executescript("""
        CREATE TABLE tasks (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT, details TEXT,
                            status TEXT, priority TEXT, tag TEXT, due_date TEXT);
        CREATE TABLE user_settings (user_id INTEGER PRIMARY KEY, theme TEXT, timezone TEXT, week_start TEXT);
    """)
    conn.close()

    os.environ["TASKMANAGER_DB"] = str(path)
    import main
    importlib.reload(main)

    conn = sqlite3.connect(path)
    task_cols = {r[1] for r in conn.execute("PRAGMA table_info(tasks)")}
    settings_cols = {r[1] for r in conn.execute("PRAGMA table_info(user_settings)")}
    conn.close()
    assert "completed_at" in task_cols
    assert {"daily_goal", "weekly_goal"} <= settings_cols

