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

База (`taskmanager.db`) створюється автоматично при першому запуску. Щоб скинути дані — зупинити сервер і видалити файл.

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
| GET | `/me` | поточний юзер | ✓ |
| PATCH | `/me` | змінити ім'я / телефон / email | ✓ |
| POST | `/me/password` | змінити пароль (`current_password`, `new_password`) | ✓ |
| DELETE | `/me` | видалити акаунт разом із задачами | ✓ |
| GET | `/settings` | налаштування: `theme`, `timezone`, `week_start` | ✓ |
| PATCH | `/settings` | змінити налаштування | ✓ |
| GET | `/tasks` | список задач | ✓ |
| POST | `/tasks` | створити задачу | ✓ |
| PATCH | `/tasks/{id}` | оновити задачу (напр. `{"status": "done"}`) | ✓ |
| DELETE | `/tasks/{id}` | видалити задачу | ✓ |

Фільтри для `GET /tasks` (необов'язкові, можна комбінувати):
- `status_filter` — `todo`, `in_progress`, `done`
- `due_date` — конкретний день, напр. `2026-11-15`
- `due_from` / `due_to` — діапазон дат включно

Значення полів:
- статус: `todo`, `in_progress`, `done`
- пріоритет: `low`, `medium`, `high`
- тема: `system`, `light`, `dark`
- початок тижня: `monday`, `sunday`
- дати: `YYYY-MM-DD`

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

## Коди відповідей

| Код | Коли |
|---|---|
| 200 / 201 / 204 | успіх |
| 400 | невірний поточний пароль при зміні пароля |
| 401 | немає токена, токен недійсний, невірний логін або пароль |
| 404 | задача не знайдена (або належить іншому юзеру) |
| 409 | email уже зареєстрований |
| 422 | невалідні дані (у відповіді видно, яке поле не пройшло перевірку) |

## Перегляд бази

Будь-який SQLite-клієнт, напр. DB Browser for SQLite.
