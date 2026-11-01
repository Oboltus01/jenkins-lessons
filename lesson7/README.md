# Lesson 7 — Parallel Execution & Timeout Guards

Источник преподавателя: [коммит f02e213](https://github.com/sirgray/specter-jen/commit/f02e21394921dea93fc784bb6eb8b660e470b784), 01.11.2026.

## Файлы

- [parallel-hours1-2.groovy](parallel-hours1-2.groovy) — Hours 1–2: `PARALLEL_THREADS`, фоновые Bash-процессы, `wait`, агрегация журналов
- [timeout-hours3-4.groovy](timeout-hours3-4.groovy) — Hours 3–4: watchdog, ограничение времени 3 с, обработка ошибок и cleanup

Эти две версии **сохранены как исходный код Сергея**, который мы применили на занятии. Они не являются улучшенной или production-версией: оба скрипта перезаписывают builders одной Job `lesson7-parallel-demo`, а во втором остаются вопросы корректного завершения дочерних процессов.

## Что реально проверено в Killercoda 01.11.2026

| Этап | Проверка | Результат |
|---|---|---|
| Hours 1–2 | Job `lesson7-parallel-demo`, `PARALLEL_THREADS=4` | Build #1 `SUCCESS` |
| Hours 1–2 | 4 сообщения SPAWNED и 4 SYNC SUCCESS | Подтверждено |
| Hours 3–4 | Тот же Job после замены shell builder | Build #2 `FAILURE` — **ожидаемо** |
| Hours 3–4 | Watchdog limit 3s, SIGTERM и cleanup | Сообщения в логе подтверждены |

Фрагмент второго лога:

```text
--> Worker spawned with PID: 121
--> Watchdog initialized with PID: 123 (Limit: 3s)
[TIMEOUT EXCEEDED] Worker PID 121 passed 3s threshold!
[TIMEOUT EXCEEDED] Dispatching SIGTERM to force worker termination...
[FAILURE] Worker execution interrupted or terminated by watchdog!
[CLEANUP] Executing process isolation sweep (Exit Code: 1)...
Finished: FAILURE
```

## Как загрузить в Jenkins, уже запущенный через lesson5/fast-setup.sh

```bash
PASS=$(cat /root/.jenkins-lesson5-fast/admin-password)
COOKIE_FILE=$(mktemp)
CRUMB=$(curl -fsS -u "admin:$PASS" -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
  http://localhost:8080/crumbIssuer/api/json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["crumbRequestField"] + ": " + d["crumb"])')

# Выберите один файл: сначала parallel-hours1-2.groovy, затем timeout-hours3-4.groovy
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lessons/main/lesson7/parallel-hours1-2.groovy -o /tmp/lesson7.groovy
curl -fsS -u "admin:$PASS" -b "$COOKIE_FILE" -H "$CRUMB" \
  --data-urlencode "script@/tmp/lesson7.groovy" http://localhost:8080/scriptText
rm -f "$COOKIE_FILE"
```

Ожидаем `LESSON7_HOURS1_2_PROVISIONED`. Для Hours 3–4 поменяйте имя файла в URL на `timeout-hours3-4.groovy` и повторно получите crumb/cookie; ожидаем `LESSON7_HOURS3_4_PROVISIONED`. Для POST запуска сборки используйте тот же способ авторизации. **Загрузка второго файла меняет конфигурацию той же Job**, сохраняя историю.

## Что улучшим после урока

1. Проверку числа `PARALLEL_THREADS` (положительное целое и разумный предел).
2. Независимые Job или явный режим, чтобы версия Hours 3–4 не заменяла Hours 1–2.
3. Надёжную очистку дочерних процессов и обработку SIGTERM.
4. Проверку завершения Jenkins Build через API вместо фиксированного `sleep 5/6`.

**Статус:** исходные Groovy-файлы проверены в занятии; будущие исправленные варианты ещё не тестировались.
