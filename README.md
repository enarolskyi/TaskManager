# TaskManager

A full-stack task manager built from scratch: a native **iOS app (SwiftUI)** and a **REST API backend (FastAPI + SQLite)** with automated API tests.

## Features

**iOS app**
- Welcome screen, sign up, log in and password reset (token-based auth, session restored on launch)
- **Plan** — tasks split into *To-do / In progress / Complete*, priorities, tags, due dates
- Search, filters (priority, tag, due date: today / this week / overdue) and sorting
- Tap a task to edit it; swipe to complete, move or delete
- **Calendar** — week strip with task indicators, tasks for the selected day, quick add for that date
- **Productivity** — daily / weekly goals, 7-day chart (Swift Charts), streak, totals
- **Reminders** — local notifications on due dates and a morning overview, configurable time
- **More** — edit profile, change password, delete account, theme (System / Light / Dark), timezone, first day of week
- Custom app icon (light / dark / tinted), dark mode, pull-to-refresh
- `accessibilityIdentifier` on interactive elements — ready for XCUITest

**Backend**
- Auth: register / login / logout with hashed passwords (PBKDF2 + salt)
- Password reset via one-time 6-digit code: hashed, 15 min TTL, 5 attempts, 60 s resend cooldown
- Tasks CRUD with filters (status, due date / range, search, tags, priority) and sorting
- Profile and user settings endpoints
- Stats endpoint: completed tasks per day (in the user's timezone), streak, goals; SQLite schema migrations
- Input validation with Pydantic, consistent error responses (401 / 404 / 409 / 422)
- Swagger UI at `/docs`

## Tech stack

| Layer | Tech |
|---|---|
| iOS | Swift, SwiftUI, Observation (`@Observable`), async/await, URLSession |
| Architecture | MVVM |
| Backend | Python, FastAPI, Pydantic, SQLite |
| Tests | pytest (74 API tests), GitHub Actions CI |

## Project structure

```
TaskManager/            iOS app
├── App/                entry point, root navigation
├── Models/             data models and API DTOs
├── Networking/         APIClient — all HTTP requests
├── ViewModels/         AuthViewModel, TaskStore, SettingsStore, AuthRouter
├── Views/              Welcome, Auth, Plan, Calendar, More, reusable Components
└── Utils/              Validator
backend/                FastAPI server + tests
```

## Run locally

**Backend**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt pytest httpx
uvicorn main:app --reload --host 0.0.0.0
```
Swagger: http://127.0.0.1:8000/docs

**Tests**
```bash
cd backend && pytest -v
```

**iOS app**
Open `TaskManager.xcodeproj` in Xcode and run on a simulator (⌘R).
To run on a real iPhone, set your Mac's local IP in `Networking/APIClient.swift` (`macIP`).

## API overview

| Method | Path | Description |
|---|---|---|
| POST | `/auth/register` | create account → token |
| POST | `/auth/login` | log in → token |
| POST | `/auth/logout` | invalidate token |
| POST | `/auth/forgot-password` | send a 6-digit reset code (same response for any email) |
| POST | `/auth/reset-password` | set a new password with the code |
| GET / PATCH / DELETE | `/me` | profile |
| POST | `/me/password` | change password |
| GET / PATCH | `/settings` | theme, timezone, week start, daily / weekly goal |
| GET | `/stats` | completed per day, streak, totals (`days`, default 7) |
| GET | `/tasks` | list (`status_filter`, `due_date`, `due_from`, `due_to`, `search`, `tag`, `priority`, `sort`) |
| POST | `/tasks` | create |
| PATCH / DELETE | `/tasks/{id}` | update / delete |
