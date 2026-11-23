"""
Шар бази даних. Той самий код працює і на SQLite (локально / тести),
і на PostgreSQL (хмара) — залежно від DATABASE_URL.

Тонка обгортка над SQLAlchemy зберігає звичний стиль sqlite3:
    db.execute("... WHERE id = ?", (value,)).fetchone()["col"]
тож ендпоінти майже не змінюються, а SQLAlchemy бере на себе
пул з'єднань і відмінності діалектів.
"""
import os
import re

from sqlalchemy import (Column, ForeignKey, Integer, MetaData, String, Table,
                        Text, create_engine, event, inspect, text)
from sqlalchemy.engine import Engine
from sqlalchemy.exc import IntegrityError


def _database_url() -> str:
    url = os.environ.get("DATABASE_URL")
    if url:
        # Neon/Render дають "postgres://" або "postgresql://", а нам треба явний драйвер psycopg (v3)
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql+psycopg://", 1)
        elif url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+psycopg://", 1)
        return url
    # Локально й у тестах — SQLite-файл (сумісність зі старим TASKMANAGER_DB)
    path = os.environ.get("TASKMANAGER_DB", "taskmanager.db")
    return f"sqlite:///{path}"


DATABASE_URL = _database_url()
IS_SQLITE = DATABASE_URL.startswith("sqlite")

# pool_pre_ping: Neon засинає без активності — перевіряємо з'єднання перед запитом,
# щоб перший запит після пробудження не падав на "мертвому" конекті
engine: Engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    connect_args={"check_same_thread": False} if IS_SQLITE else {},
)


# SQLite не вмикає зовнішні ключі сам — потрібно на кожне з'єднання
if IS_SQLITE:
    @event.listens_for(engine, "connect")
    def _enable_fk(dbapi_connection, _):
        dbapi_connection.execute("PRAGMA foreign_keys = ON")


# --- Схема ---
# Дати зберігаємо рядками (Text), як і раніше: "2026-11-15" та ISO-datetime.
# Так порівняння й поведінка однакові на обох базах.

metadata = MetaData()

users = Table(
    "users", metadata,
    Column("id", Integer, primary_key=True),
    Column("full_name", Text, nullable=False),
    Column("phone", Text, nullable=False),
    Column("email", Text, nullable=False, unique=True),
    Column("password_hash", Text, nullable=False),
)

tokens = Table(
    "tokens", metadata,
    Column("token", String(64), primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
)

tasks = Table(
    "tasks", metadata,
    Column("id", Integer, primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
    Column("title", Text, nullable=False),
    Column("details", Text, nullable=False, server_default=""),
    Column("status", Text, nullable=False, server_default="todo"),
    Column("priority", Text, nullable=False, server_default="medium"),
    Column("tag", Text, nullable=False, server_default="General"),
    Column("due_date", Text, nullable=False),
    Column("completed_at", Text),
    Column("recurrence", Text, nullable=False, server_default="none"),   # none/daily/weekly/monthly
)

subtasks = Table(
    "subtasks", metadata,
    Column("id", Integer, primary_key=True),
    Column("task_id", Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False),
    Column("title", Text, nullable=False),
    Column("is_done", Integer, nullable=False, server_default="0"),   # 0/1 — портативно між базами
    Column("position", Integer, nullable=False, server_default="0"),
)

user_settings = Table(
    "user_settings", metadata,
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("theme", Text, nullable=False, server_default="system"),
    Column("timezone", Text, nullable=False, server_default="UTC"),
    Column("week_start", Text, nullable=False, server_default="monday"),
    Column("daily_goal", Integer, nullable=False, server_default="5"),
    Column("weekly_goal", Integer, nullable=False, server_default="30"),
)

password_resets = Table(
    "password_resets", metadata,
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("code_hash", Text, nullable=False),
    Column("expires_at", Text, nullable=False),
    Column("attempts", Integer, nullable=False, server_default="0"),
    Column("created_at", Text, nullable=False),
)

def init_db():
    metadata.create_all(engine)
    _migrate()


def _migrate():
    """Додає колонки, яких немає в базі, створеній старішою версією.
    На новій (хмарній) базі create_all одразу створює все, і міграція нічого не робить."""
    inspector = inspect(engine)
    existing = {t: {c["name"] for c in inspector.get_columns(t)} for t in inspector.get_table_names()}
    additions = [
        ("tasks", "completed_at", "TEXT"),
        ("user_settings", "daily_goal", "INTEGER NOT NULL DEFAULT 5"),
        ("user_settings", "weekly_goal", "INTEGER NOT NULL DEFAULT 30"),
        ("tasks", "recurrence", "TEXT NOT NULL DEFAULT 'none'"),
    ]
    with engine.begin() as conn:
        for table_, column, decl in additions:
            if table_ in existing and column not in existing[table_]:
                conn.execute(text(f"ALTER TABLE {table_} ADD COLUMN {column} {decl}"))
        # due_date тепер з часом: старим задачам (лише дата) проставляємо 09:00
        if "tasks" in existing:
            conn.execute(text(
                "UPDATE tasks SET due_date = due_date || 'T09:00:00' "
                "WHERE due_date IS NOT NULL AND due_date NOT LIKE '%T%'"))


# --- Обгортка з'єднання у стилі sqlite3 ---

_PLACEHOLDER = re.compile(r"\?")


class _Cursor:
    """Повертає рядки як dict, щоб працювало row["col"], як у sqlite3.Row"""
    def __init__(self, result):
        self.lastrowid = None
        self._rows = None
        if result.returns_rows:
            self._rows = [dict(r._mapping) for r in result]
            # INSERT ... RETURNING id → lastrowid
            if self._rows and "id" in self._rows[0]:
                self.lastrowid = self._rows[0]["id"]
        else:
            self.rowcount = result.rowcount

    def fetchone(self):
        return self._rows[0] if self._rows else None

    def fetchall(self):
        return self._rows or []

    def __iter__(self):
        return iter(self._rows or [])


class Database:
    def __init__(self, connection):
        self._conn = connection

    def execute(self, sql: str, params=()):
        # ? → :p0, :p1 ... (наші запити не містять ? у рядкових літералах)
        counter = iter(range(10_000))
        named = _PLACEHOLDER.sub(lambda _: f":p{next(counter)}", sql)
        bind = {f"p{i}": v for i, v in enumerate(params)}
        return _Cursor(self._conn.execute(text(named), bind))

    def commit(self):
        self._conn.commit()


def get_db():
    conn = engine.connect()
    try:
        yield Database(conn)
    finally:
        conn.close()
