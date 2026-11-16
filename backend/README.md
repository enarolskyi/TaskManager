# TaskManager API

REST API для iOS-застосунку TaskManager. FastAPI + SQLite.

## Запуск

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt pytest httpx
uvicorn main:app --reload --host 0.0.0.0
```

Swagger: http://127.0.0.1:8000/docs

База (`taskmanager.db`) створюється автоматично при першому запуску, нові колонки додаються міграцією при старті. Щоб скинути дані — зупинити сервер і видалити файл.

## Тести

```bash
pytest -v
```

Кожен тест працює з окремою тимчасовою БД, тому робоча база не зачіпається.

## Авторизація

Після `/auth/register` або `/auth/login` сервер повертає токен. Він передається в заголовку:

```
Authorization: Bearer <token>
```

У Swagger: виконати `/auth/login` → скопіювати `token` → **Authorize** → вставити токен.

## Ендпоінти

| Метод | Шлях | Опис | Токен |
|---|---|---|---|
| POST | `/auth/register` | реєстрація → token + user | — |
| POST | `/auth/login` | логін → token + user | — |
| POST | `/auth/logout` | інвалідує токен | ✓ |
| POST | `/auth/forgot-password` | надсилає 6-значний код для скидання пароля | — |
| POST | `/auth/reset-password` | новий пароль за кодом (`email`, `code`, `new_password`) | — |
| GET | `/me` | поточний юзер | ✓ |
| PATCH | `/me` | змінити ім'я / телефон / email | ✓ |
| POST | `/me/password` | змінити пароль (`current_password`, `new_password`) | ✓ |
| DELETE | `/me` | видалити акаунт разом із задачами | ✓ |
| GET | `/settings` | налаштування: `theme`, `timezone`, `week_start`, `daily_goal`, `weekly_goal` | ✓ |
| PATCH | `/settings` | змінити налаштування | ✓ |
| GET | `/stats` | статистика: виконані по днях, streak, підсумки (`?days=7`, 1–90) | ✓ |
| GET | `/tasks` | список задач | ✓ |
| POST | `/tasks` | створити задачу | ✓ |
| PATCH | `/tasks/{id}` | оновити задачу (напр. `{"status": "done"}`) | ✓ |
| DELETE | `/tasks/{id}` | видалити задачу | ✓ |

Фільтри для `GET /tasks` (необов'язкові, можна комбінувати):
- `status_filter` — `todo`, `in_progress`, `done`
- `due_date` — конкретний день, напр. `2026-11-15`
- `due_from` / `due_to` — діапазон дат включно
- `search` — пошук у назві, описі й тезі (без урахування регістру)
- `tag`, `priority` — можна кілька: `?tag=Home&tag=Sport&priority=high`
- `sort` — `created` (за замовчуванням), `due_date`, `priority` (high першим), `name`

Значення полів:
- статус: `todo`, `in_progress`, `done`
- пріоритет: `low`, `medium`, `high`
- тема: `system`, `light`, `dark`
- початок тижня: `monday`, `sunday`
- дати: `YYYY-MM-DD`; `completed_at` — ISO datetime в UTC, ставиться автоматично при переході в `done`
- цілі: `daily_goal`, `weekly_goal` — від 1 до 100

## Приклад (curl)

```bash
# реєстрація
curl -X POST http://127.0.0.1:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"full_name":"Ed","phone":"+380671234567","email":"ed@test.com","password":"Test1234"}'

# створити задачу
curl -X POST http://127.0.0.1:8000/tasks \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"title":"Water the flowers","priority":"low","tag":"Home","due_date":"2026-11-15"}'
```

## Скидання пароля

- `forgot-password` завжди відповідає 200 з однаковим текстом — щоб не можна було перевірити, чи email зареєстрований
- Код: 6 цифр, у БД зберігається хеш, діє 15 хв, одноразовий, максимум 5 спроб
- Повторний запит коду — не частіше ніж раз на 60 с; новий код замінює попередній
- Після скидання всі сесії юзера інвалідуються
- **Поки пошти немає:** код друкується в консолі uvicorn (`send_email` у `main.py`)

## Коди відповідей

| Код | Коли |
|---|---|
| 200 / 201 / 204 | успіх |
| 400 | невірний поточний пароль при зміні пароля; невірний / прострочений код скидання |
| 401 | немає токена, токен недійсний, невірний логін або пароль |
| 404 | задача не знайдена (або належить іншому юзеру) |
| 409 | email уже зареєстрований |
| 422 | невалідні дані (у відповіді видно, яке поле не пройшло перевірку) |

## Перегляд бази

Будь-який SQLite-клієнт, напр. DB Browser for SQLite.
