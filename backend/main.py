"""
TaskManager API (FastAPI + SQLite)

uvicorn main:app --reload
"""
import hashlib
import os
import re
import secrets
import sqlite3
from datetime import date
from enum import Enum
from typing import Annotated, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import AfterValidator, BaseModel, Field, field_validator

DB_PATH = os.environ.get("TASKMANAGER_DB", "taskmanager.db")

app = FastAPI(title="TaskManager API", version="1.1")


# --- DB ---

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name     TEXT NOT NULL,
            phone         TEXT NOT NULL,
            email         TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS tokens (
            token   TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS tasks (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title    TEXT NOT NULL,
            details  TEXT NOT NULL DEFAULT '',
            status   TEXT NOT NULL DEFAULT 'todo',
            priority TEXT NOT NULL DEFAULT 'medium',
            tag      TEXT NOT NULL DEFAULT 'General',
            due_date TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_settings (
            user_id    INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            theme      TEXT NOT NULL DEFAULT 'system',
            timezone   TEXT NOT NULL DEFAULT 'UTC',
            week_start TEXT NOT NULL DEFAULT 'monday'
        );
    """)
    conn.commit()
    conn.close()


init_db()


# --- Passwords (PBKDF2 + salt) ---

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return f"{salt}${digest}"


def verify_password(password: str, stored: str) -> bool:
    salt, digest = stored.split("$")
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 100_000).hex()
    return secrets.compare_digest(check, digest)


# --- Validation (ті самі правила, що в iOS Validator) ---

EMAIL_RE = re.compile(r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$", re.IGNORECASE)


def validate_full_name(v: str) -> str:
    if len(v.strip()) < 2:
        raise ValueError("Full name is too short")
    return v.strip()


def validate_phone(v: str) -> str:
    digits = [c for c in v if c.isdigit()]
    if not 10 <= len(digits) <= 15:
        raise ValueError("Phone must contain 10-15 digits")
    return v


def validate_email(v: str) -> str:
    if not EMAIL_RE.match(v.strip()):
        raise ValueError("Invalid email format")
    return v.strip().lower()


def validate_password(v: str) -> str:
    if len(v) < 8 or not any(c.isupper() for c in v) or not any(c.isdigit() for c in v):
        raise ValueError("Password: 8+ characters, 1 uppercase, 1 number")
    return v


FullName = Annotated[str, AfterValidator(validate_full_name)]
Phone = Annotated[str, AfterValidator(validate_phone)]
Email = Annotated[str, AfterValidator(validate_email)]
Password = Annotated[str, AfterValidator(validate_password)]

MAX_TAG_LENGTH = 20   # той самий ліміт, що в iOS (TaskItem.maxTagLength)
Tag = Annotated[str, Field(max_length=MAX_TAG_LENGTH)]


# --- Schemas ---

class TaskStatus(str, Enum):
    todo = "todo"
    in_progress = "in_progress"
    done = "done"


class TaskPriority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class Theme(str, Enum):
    system = "system"
    light = "light"
    dark = "dark"


class WeekStart(str, Enum):
    monday = "monday"
    sunday = "sunday"


class RegisterRequest(BaseModel):
    full_name: FullName
    phone: Phone
    email: Email
    password: Password


class LoginRequest(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: int
    full_name: str
    phone: str
    email: str


class UserUpdate(BaseModel):
    full_name: Optional[FullName] = None
    phone: Optional[Phone] = None
    email: Optional[Email] = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: Password


class AuthResponse(BaseModel):
    token: str
    user: UserOut


class SettingsOut(BaseModel):
    theme: Theme
    timezone: str
    week_start: WeekStart


class SettingsUpdate(BaseModel):
    theme: Optional[Theme] = None
    timezone: Optional[str] = None
    week_start: Optional[WeekStart] = None

    @field_validator("timezone")
    @classmethod
    def check_timezone(cls, v):
        if v is None:
            return v
        try:
            ZoneInfo(v)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError("Unknown timezone")
        return v


class TaskCreate(BaseModel):
    title: str
    details: str = ""
    status: TaskStatus = TaskStatus.todo
    priority: TaskPriority = TaskPriority.medium
    tag: Tag = "General"
    due_date: date

    @field_validator("title")
    @classmethod
    def check_title(cls, v):
        if not v.strip():
            raise ValueError("Title is required")
        return v.strip()


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    details: Optional[str] = None
    status: Optional[TaskStatus] = None
    priority: Optional[TaskPriority] = None
    tag: Optional[Tag] = None
    due_date: Optional[date] = None


class TaskSort(str, Enum):
    created = "created"
    due_date = "due_date"
    priority = "priority"
    name = "name"


class TaskOut(BaseModel):
    id: int
    title: str
    details: str
    status: TaskStatus
    priority: TaskPriority
    tag: str
    due_date: date


def clean_changes(model: BaseModel) -> dict:
    """Тільки передані й не-null поля; enum/date → рядки для SQLite"""
    changes = model.model_dump(exclude_unset=True, exclude_none=True)
    for key, value in changes.items():
        if isinstance(value, Enum):
            changes[key] = value.value
        elif isinstance(value, date):
            changes[key] = value.isoformat()
    return changes


# --- Auth helpers ---

bearer = HTTPBearer(auto_error=False)


def current_token(creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer)) -> str:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    return creds.credentials


def current_user(token: str = Depends(current_token),
                 db: sqlite3.Connection = Depends(get_db)) -> sqlite3.Row:
    user = db.execute(
        "SELECT users.* FROM tokens JOIN users ON users.id = tokens.user_id WHERE token = ?",
        (token,),
    ).fetchone()
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return user


def user_out(row) -> UserOut:
    return UserOut(id=row["id"], full_name=row["full_name"], phone=row["phone"], email=row["email"])


def issue_token(db, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    db.execute("INSERT INTO tokens (token, user_id) VALUES (?, ?)", (token, user_id))
    db.commit()
    return token


# --- Auth ---

@app.post("/auth/register", response_model=AuthResponse, status_code=201, tags=["auth"])
def register(body: RegisterRequest, db: sqlite3.Connection = Depends(get_db)):
    exists = db.execute("SELECT 1 FROM users WHERE email = ?", (body.email,)).fetchone()
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "User with this email already exists")

    cur = db.execute(
        "INSERT INTO users (full_name, phone, email, password_hash) VALUES (?, ?, ?, ?)",
        (body.full_name, body.phone, body.email, hash_password(body.password)),
    )
    db.commit()
    user = db.execute("SELECT * FROM users WHERE id = ?", (cur.lastrowid,)).fetchone()
    return AuthResponse(token=issue_token(db, user["id"]), user=user_out(user))


@app.post("/auth/login", response_model=AuthResponse, tags=["auth"])
def login(body: LoginRequest, db: sqlite3.Connection = Depends(get_db)):
    user = db.execute("SELECT * FROM users WHERE email = ?",
                      (body.email.strip().lower(),)).fetchone()
    # Одна помилка для обох випадків, щоб не розкривати, які email зареєстровані
    if user is None or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password")
    return AuthResponse(token=issue_token(db, user["id"]), user=user_out(user))


@app.post("/auth/logout", status_code=204, tags=["auth"])
def logout(user=Depends(current_user), token: str = Depends(current_token),
           db: sqlite3.Connection = Depends(get_db)):
    db.execute("DELETE FROM tokens WHERE token = ?", (token,))
    db.commit()


# --- Profile ---

@app.get("/me", response_model=UserOut, tags=["profile"])
def me(user=Depends(current_user)):
    return user_out(user)


@app.patch("/me", response_model=UserOut, tags=["profile"])
def update_me(body: UserUpdate, user=Depends(current_user),
              db: sqlite3.Connection = Depends(get_db)):
    changes = clean_changes(body)

    if "email" in changes:
        taken = db.execute("SELECT 1 FROM users WHERE email = ? AND id != ?",
                           (changes["email"], user["id"])).fetchone()
        if taken:
            raise HTTPException(status.HTTP_409_CONFLICT, "User with this email already exists")

    if changes:
        sets = ", ".join(f"{k} = ?" for k in changes)   # ключі лише з полів схеми
        db.execute(f"UPDATE users SET {sets} WHERE id = ?", (*changes.values(), user["id"]))
        db.commit()
    return user_out(db.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone())


@app.post("/me/password", status_code=204, tags=["profile"])
def change_password(body: ChangePasswordRequest, user=Depends(current_user),
                    token: str = Depends(current_token), db: sqlite3.Connection = Depends(get_db)):
    if not verify_password(body.current_password, user["password_hash"]):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Current password is incorrect")

    db.execute("UPDATE users SET password_hash = ? WHERE id = ?",
               (hash_password(body.new_password), user["id"]))
    # Інші сесії інвалідуємо, поточну лишаємо
    db.execute("DELETE FROM tokens WHERE user_id = ? AND token != ?", (user["id"], token))
    db.commit()


@app.delete("/me", status_code=204, tags=["profile"])
def delete_me(user=Depends(current_user), db: sqlite3.Connection = Depends(get_db)):
    # токени, задачі й налаштування видаляються через ON DELETE CASCADE
    db.execute("DELETE FROM users WHERE id = ?", (user["id"],))
    db.commit()


# --- Settings ---

def get_settings_row(db, user_id: int):
    db.execute("INSERT OR IGNORE INTO user_settings (user_id) VALUES (?)", (user_id,))
    db.commit()
    return db.execute("SELECT theme, timezone, week_start FROM user_settings WHERE user_id = ?",
                      (user_id,)).fetchone()


@app.get("/settings", response_model=SettingsOut, tags=["settings"])
def get_settings(user=Depends(current_user), db: sqlite3.Connection = Depends(get_db)):
    return SettingsOut(**dict(get_settings_row(db, user["id"])))


@app.patch("/settings", response_model=SettingsOut, tags=["settings"])
def update_settings(body: SettingsUpdate, user=Depends(current_user),
                    db: sqlite3.Connection = Depends(get_db)):
    get_settings_row(db, user["id"])
    changes = clean_changes(body)
    if changes:
        sets = ", ".join(f"{k} = ?" for k in changes)
        db.execute(f"UPDATE user_settings SET {sets} WHERE user_id = ?",
                   (*changes.values(), user["id"]))
        db.commit()
    return SettingsOut(**dict(get_settings_row(db, user["id"])))


# --- Tasks ---

def task_out(row) -> TaskOut:
    return TaskOut(**dict(row))


def get_own_task(db, task_id: int, user_id: int):
    row = db.execute(
        "SELECT id, title, details, status, priority, tag, due_date FROM tasks "
        "WHERE id = ? AND user_id = ?", (task_id, user_id)).fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    return row


@app.get("/tasks", response_model=list[TaskOut], tags=["tasks"])
def list_tasks(status_filter: Optional[TaskStatus] = None,
               due_date: Optional[date] = None,
               due_from: Optional[date] = None,
               due_to: Optional[date] = None,
               search: Optional[str] = None,
               tag: Optional[list[str]] = Query(default=None),
               priority: Optional[list[TaskPriority]] = Query(default=None),
               sort: TaskSort = TaskSort.created,
               user=Depends(current_user), db: sqlite3.Connection = Depends(get_db)):
    """
    Фільтри необов'язкові й комбінуються; due_from/due_to — включно.
    tag і priority можна передавати кілька разів: ?tag=Home&tag=Sport
    """
    sql = "SELECT id, title, details, status, priority, tag, due_date FROM tasks WHERE user_id = ?"
    params: list = [user["id"]]
    if status_filter:
        sql += " AND status = ?"
        params.append(status_filter.value)
    # ISO-дати коректно порівнюються як рядки
    if due_date:
        sql += " AND due_date = ?"
        params.append(due_date.isoformat())
    if due_from:
        sql += " AND due_date >= ?"
        params.append(due_from.isoformat())
    if due_to:
        sql += " AND due_date <= ?"
        params.append(due_to.isoformat())
    if search and search.strip():
        # LIKE у SQLite нечутливий до регістру для латиниці
        sql += " AND (title LIKE ? OR details LIKE ? OR tag LIKE ?)"
        pattern = f"%{search.strip()}%"
        params += [pattern, pattern, pattern]
    if tag:
        sql += f" AND tag IN ({', '.join('?' * len(tag))})"
        params += tag
    if priority:
        sql += f" AND priority IN ({', '.join('?' * len(priority))})"
        params += [p.value for p in priority]

    order_by = {
        TaskSort.created: "id",
        TaskSort.due_date: "due_date, id",
        TaskSort.priority: "CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END, id",
        TaskSort.name: "title COLLATE NOCASE, id",
    }
    sql += f" ORDER BY {order_by[sort]}"
    return [task_out(r) for r in db.execute(sql, params).fetchall()]


@app.post("/tasks", response_model=TaskOut, status_code=201, tags=["tasks"])
def create_task(body: TaskCreate, user=Depends(current_user),
                db: sqlite3.Connection = Depends(get_db)):
    cur = db.execute(
        "INSERT INTO tasks (user_id, title, details, status, priority, tag, due_date) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (user["id"], body.title, body.details, body.status.value, body.priority.value,
         body.tag or "General", body.due_date.isoformat()),
    )
    db.commit()
    return task_out(get_own_task(db, cur.lastrowid, user["id"]))


@app.patch("/tasks/{task_id}", response_model=TaskOut, tags=["tasks"])
def update_task(task_id: int, body: TaskUpdate, user=Depends(current_user),
                db: sqlite3.Connection = Depends(get_db)):
    get_own_task(db, task_id, user["id"])  # 404 для чужої/неіснуючої

    changes = clean_changes(body)
    if "title" in changes and not changes["title"].strip():
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Title is required")

    if changes:
        sets = ", ".join(f"{k} = ?" for k in changes)
        db.execute(f"UPDATE tasks SET {sets} WHERE id = ?", (*changes.values(), task_id))
        db.commit()
    return task_out(get_own_task(db, task_id, user["id"]))


@app.delete("/tasks/{task_id}", status_code=204, tags=["tasks"])
def delete_task(task_id: int, user=Depends(current_user),
                db: sqlite3.Connection = Depends(get_db)):
    get_own_task(db, task_id, user["id"])
    db.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
    db.commit()
