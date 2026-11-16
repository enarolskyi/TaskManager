"""
TaskManager API (FastAPI + SQLAlchemy)

Працює на SQLite (локально) і PostgreSQL (хмара) — залежно від DATABASE_URL.
uvicorn main:app --reload
"""
import hashlib
import re
import secrets
from datetime import date, datetime, timedelta, timezone
from enum import Enum
from typing import Annotated, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import AfterValidator, BaseModel, Field, field_validator

from database import Database, get_db, init_db

app = FastAPI(title="TaskManager API", version="2.0")

# Дозволяємо запити з браузера (напр. Swagger на іншому домені). Нативному застосунку CORS не потрібен.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    email: str
    code: Annotated[str, Field(pattern=r"^\d{6}$")]
    new_password: Password


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: Password


class AuthResponse(BaseModel):
    token: str
    user: UserOut


Goal = Annotated[int, Field(ge=1, le=100)]


class SettingsOut(BaseModel):
    theme: Theme
    timezone: str
    week_start: WeekStart
    daily_goal: int
    weekly_goal: int


class SettingsUpdate(BaseModel):
    theme: Optional[Theme] = None
    timezone: Optional[str] = None
    week_start: Optional[WeekStart] = None
    daily_goal: Optional[Goal] = None
    weekly_goal: Optional[Goal] = None

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
    completed_at: Optional[datetime] = None


def clean_changes(model: BaseModel) -> dict:
    """Тільки передані й не-null поля; enum/date → рядки"""
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
                 db: Database = Depends(get_db)):
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
def register(body: RegisterRequest, db: Database = Depends(get_db)):
    exists = db.execute("SELECT 1 FROM users WHERE email = ?", (body.email,)).fetchone()
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "User with this email already exists")

    cur = db.execute(
        "INSERT INTO users (full_name, phone, email, password_hash) VALUES (?, ?, ?, ?) RETURNING id",
        (body.full_name, body.phone, body.email, hash_password(body.password)),
    )
    user_id = cur.lastrowid
    db.commit()
    user = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return AuthResponse(token=issue_token(db, user["id"]), user=user_out(user))


@app.post("/auth/login", response_model=AuthResponse, tags=["auth"])
def login(body: LoginRequest, db: Database = Depends(get_db)):
    user = db.execute("SELECT * FROM users WHERE email = ?",
                      (body.email.strip().lower(),)).fetchone()
    # Одна помилка для обох випадків, щоб не розкривати, які email зареєстровані
    if user is None or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password")
    return AuthResponse(token=issue_token(db, user["id"]), user=user_out(user))


@app.post("/auth/logout", status_code=204, tags=["auth"])
def logout(user=Depends(current_user), token: str = Depends(current_token),
           db: Database = Depends(get_db)):
    db.execute("DELETE FROM tokens WHERE token = ?", (token,))
    db.commit()


# --- Password reset ---

RESET_CODE_TTL = timedelta(minutes=15)
RESET_MAX_ATTEMPTS = 5
RESET_RESEND_COOLDOWN = timedelta(seconds=60)
INVALID_CODE = "Invalid or expired code"


def send_email(to: str, subject: str, body: str):
    """Поки бекенд локальний — "лист" просто друкується в консоль uvicorn.
    Після деплою тут буде справжня відправка (SMTP / поштовий сервіс)."""
    print(f"\n📧 To: {to}\n   Subject: {subject}\n   {body}\n", flush=True)


@app.post("/auth/forgot-password", tags=["auth"])
def forgot_password(body: ForgotPasswordRequest, db: Database = Depends(get_db)):
    # Відповідь завжди однакова — щоб не можна було перевірити, чи зареєстрований email
    response = {"detail": "If this email is registered, a reset code has been sent"}

    user = db.execute("SELECT id, email FROM users WHERE email = ?",
                      (body.email.strip().lower(),)).fetchone()
    if user is None:
        return response

    now = datetime.now(timezone.utc)
    existing = db.execute("SELECT created_at FROM password_resets WHERE user_id = ?",
                          (user["id"],)).fetchone()
    if existing and now - datetime.fromisoformat(existing["created_at"]) < RESET_RESEND_COOLDOWN:
        return response   # не спамимо листами при частих натисканнях

    code = f"{secrets.randbelow(1_000_000):06d}"
    # Новий код замінює попередній (DELETE+INSERT — портативно між базами)
    db.execute("DELETE FROM password_resets WHERE user_id = ?", (user["id"],))
    db.execute(
        "INSERT INTO password_resets (user_id, code_hash, expires_at, attempts, created_at) "
        "VALUES (?, ?, ?, 0, ?)",
        (user["id"], hash_password(code), (now + RESET_CODE_TTL).isoformat(), now.isoformat()),
    )
    db.commit()

    send_email(user["email"], "Your Task Manager reset code",
               f"Reset code: {code} (valid for {int(RESET_CODE_TTL.total_seconds() // 60)} minutes)")
    return response


@app.post("/auth/reset-password", status_code=204, tags=["auth"])
def reset_password(body: ResetPasswordRequest, db: Database = Depends(get_db)):
    user = db.execute("SELECT id FROM users WHERE email = ?", (body.email.strip().lower(),)).fetchone()
    reset = None if user is None else db.execute(
        "SELECT code_hash, expires_at, attempts FROM password_resets WHERE user_id = ?",
        (user["id"],)).fetchone()
    if reset is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, INVALID_CODE)

    def drop_code():
        db.execute("DELETE FROM password_resets WHERE user_id = ?", (user["id"],))
        db.commit()

    if datetime.now(timezone.utc) > datetime.fromisoformat(reset["expires_at"]):
        drop_code()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, INVALID_CODE)

    if reset["attempts"] >= RESET_MAX_ATTEMPTS:
        drop_code()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Too many attempts. Request a new code")

    if not verify_password(body.code, reset["code_hash"]):
        db.execute("UPDATE password_resets SET attempts = attempts + 1 WHERE user_id = ?", (user["id"],))
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, INVALID_CODE)

    db.execute("UPDATE users SET password_hash = ? WHERE id = ?",
               (hash_password(body.new_password), user["id"]))
    db.execute("DELETE FROM tokens WHERE user_id = ?", (user["id"],))   # розлогінюємо всі пристрої
    db.execute("DELETE FROM password_resets WHERE user_id = ?", (user["id"],))   # код одноразовий
    db.commit()


# --- Profile ---

@app.get("/me", response_model=UserOut, tags=["profile"])
def me(user=Depends(current_user)):
    return user_out(user)


@app.patch("/me", response_model=UserOut, tags=["profile"])
def update_me(body: UserUpdate, user=Depends(current_user),
              db: Database = Depends(get_db)):
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
                    token: str = Depends(current_token), db: Database = Depends(get_db)):
    if not verify_password(body.current_password, user["password_hash"]):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Current password is incorrect")

    db.execute("UPDATE users SET password_hash = ? WHERE id = ?",
               (hash_password(body.new_password), user["id"]))
    # Інші сесії інвалідуємо, поточну лишаємо
    db.execute("DELETE FROM tokens WHERE user_id = ? AND token != ?", (user["id"], token))
    db.commit()


@app.delete("/me", status_code=204, tags=["profile"])
def delete_me(user=Depends(current_user), db: Database = Depends(get_db)):
    # токени, задачі й налаштування видаляються через ON DELETE CASCADE
    db.execute("DELETE FROM users WHERE id = ?", (user["id"],))
    db.commit()


# --- Settings ---

def get_settings_row(db, user_id: int):
    query = ("SELECT theme, timezone, week_start, daily_goal, weekly_goal "
             "FROM user_settings WHERE user_id = ?")
    row = db.execute(query, (user_id,)).fetchone()
    if row is None:
        # Пишемо тільки якщо рядка ще немає — GET не повинен щоразу блокувати базу на запис
        db.execute(
            "INSERT INTO user_settings (user_id) SELECT ? "
            "WHERE NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id = ?)",
            (user_id, user_id))
        db.commit()
        row = db.execute(query, (user_id,)).fetchone()
    return row


@app.get("/settings", response_model=SettingsOut, tags=["settings"])
def get_settings(user=Depends(current_user), db: Database = Depends(get_db)):
    return SettingsOut(**dict(get_settings_row(db, user["id"])))


@app.patch("/settings", response_model=SettingsOut, tags=["settings"])
def update_settings(body: SettingsUpdate, user=Depends(current_user),
                    db: Database = Depends(get_db)):
    get_settings_row(db, user["id"])
    changes = clean_changes(body)
    if changes:
        sets = ", ".join(f"{k} = ?" for k in changes)
        db.execute(f"UPDATE user_settings SET {sets} WHERE user_id = ?",
                   (*changes.values(), user["id"]))
        db.commit()
    return SettingsOut(**dict(get_settings_row(db, user["id"])))


# --- Tasks ---

TASK_COLUMNS = "id, title, details, status, priority, tag, due_date, completed_at"


def now_utc() -> str:
    # Без мікросекунд — так дату простіше розпарсити на iOS
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def task_out(row) -> TaskOut:
    return TaskOut(**dict(row))


def get_own_task(db, task_id: int, user_id: int):
    row = db.execute(
        f"SELECT {TASK_COLUMNS} FROM tasks "
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
               user=Depends(current_user), db: Database = Depends(get_db)):
    """
    Фільтри необов'язкові й комбінуються; due_from/due_to — включно.
    tag і priority можна передавати кілька разів: ?tag=Home&tag=Sport
    """
    sql = f"SELECT {TASK_COLUMNS} FROM tasks WHERE user_id = ?"
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
        # LOWER(...) LIKE — нечутливо до регістру й однаково на SQLite та Postgres
        sql += " AND (LOWER(title) LIKE ? OR LOWER(details) LIKE ? OR LOWER(tag) LIKE ?)"
        pattern = f"%{search.strip().lower()}%"
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
        TaskSort.name: "LOWER(title), id",
    }
    sql += f" ORDER BY {order_by[sort]}"
    return [task_out(r) for r in db.execute(sql, params).fetchall()]


@app.post("/tasks", response_model=TaskOut, status_code=201, tags=["tasks"])
def create_task(body: TaskCreate, user=Depends(current_user),
                db: Database = Depends(get_db)):
    cur = db.execute(
        "INSERT INTO tasks (user_id, title, details, status, priority, tag, due_date, completed_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
        (user["id"], body.title, body.details, body.status.value, body.priority.value,
         body.tag or "General", body.due_date.isoformat(),
         now_utc() if body.status == TaskStatus.done else None),
    )
    task_id = cur.lastrowid
    db.commit()
    return task_out(get_own_task(db, task_id, user["id"]))


@app.patch("/tasks/{task_id}", response_model=TaskOut, tags=["tasks"])
def update_task(task_id: int, body: TaskUpdate, user=Depends(current_user),
                db: Database = Depends(get_db)):
    task = get_own_task(db, task_id, user["id"])  # 404 для чужої/неіснуючої

    changes = clean_changes(body)
    if "title" in changes and not changes["title"].strip():
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Title is required")

    # completed_at ставимо тільки при переході в done, щоб повторний PATCH не зсував дату
    new_status = changes.get("status")
    if new_status == TaskStatus.done.value and task["status"] != TaskStatus.done.value:
        changes["completed_at"] = now_utc()
    elif new_status and new_status != TaskStatus.done.value:
        changes["completed_at"] = None

    if changes:
        sets = ", ".join(f"{k} = ?" for k in changes)
        db.execute(f"UPDATE tasks SET {sets} WHERE id = ?", (*changes.values(), task_id))
        db.commit()
    return task_out(get_own_task(db, task_id, user["id"]))


@app.delete("/tasks/{task_id}", status_code=204, tags=["tasks"])
def delete_task(task_id: int, user=Depends(current_user),
                db: Database = Depends(get_db)):
    get_own_task(db, task_id, user["id"])
    db.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
    db.commit()


# --- Stats (More → Productivity) ---

class DayStat(BaseModel):
    date: date
    completed: int


class StatsOut(BaseModel):
    days: list[DayStat]          # по днях, від найстарішого до сьогодні
    completed_today: int
    completed_this_week: int
    daily_goal: int
    weekly_goal: int
    streak: int                  # днів поспіль з виконаною денною ціллю
    total_completed: int
    todo: int
    in_progress: int
    overdue: int


def week_start_date(today: date, week_start: str) -> date:
    # weekday(): пн = 0 ... нд = 6
    offset = today.weekday() if week_start == WeekStart.monday.value else (today.weekday() + 1) % 7
    return today - timedelta(days=offset)


@app.get("/stats", response_model=StatsOut, tags=["stats"])
def get_stats(days: int = Query(default=7, ge=1, le=90),
              user=Depends(current_user), db: Database = Depends(get_db)):
    settings = get_settings_row(db, user["id"])
    tz = ZoneInfo(settings["timezone"])
    today = datetime.now(tz).date()

    # completed_at зберігається в UTC — переводимо в таймзону юзера, щоб день рахувався правильно
    completed_per_day: dict[date, int] = {}
    for row in db.execute("SELECT completed_at FROM tasks "
                          "WHERE user_id = ? AND status = 'done' AND completed_at IS NOT NULL",
                          (user["id"],)):
        day = datetime.fromisoformat(row["completed_at"]).astimezone(tz).date()
        completed_per_day[day] = completed_per_day.get(day, 0) + 1

    day_stats = [
        DayStat(date=day, completed=completed_per_day.get(day, 0))
        for day in (today - timedelta(days=i) for i in reversed(range(days)))
    ]

    week_start = week_start_date(today, settings["week_start"])
    completed_this_week = sum(count for day, count in completed_per_day.items() if week_start <= day <= today)

    # Сьогодні ще можна встигнути, тому незакритий сьогоднішній день серію не обриває
    daily_goal = settings["daily_goal"]
    streak = 0
    day = today if completed_per_day.get(today, 0) >= daily_goal else today - timedelta(days=1)
    while completed_per_day.get(day, 0) >= daily_goal:
        streak += 1
        day -= timedelta(days=1)

    counts = {row["status"]: row["n"] for row in db.execute(
        "SELECT status, COUNT(*) AS n FROM tasks WHERE user_id = ? GROUP BY status", (user["id"],))}
    overdue = db.execute(
        "SELECT COUNT(*) AS n FROM tasks WHERE user_id = ? AND status != 'done' AND due_date < ?",
        (user["id"], today.isoformat())).fetchone()["n"]

    return StatsOut(
        days=day_stats,
        completed_today=completed_per_day.get(today, 0),
        completed_this_week=completed_this_week,
        daily_goal=daily_goal,
        weekly_goal=settings["weekly_goal"],
        streak=streak,
        total_completed=counts.get("done", 0),
        todo=counts.get("todo", 0),
        in_progress=counts.get("in_progress", 0),
        overdue=overdue,
    )
