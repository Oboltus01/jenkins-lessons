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

## Продолжение практики 01.11.2026: Hours 5–8, Capstone, Audit

После перезапуска Killercoda Jenkins восстановлен скриптом `lesson5/fast-setup.sh`. Job `lesson7-parallel-demo` в новой сессии создан исходным Groovy для Hours 1–2 и затем последовательно перенастроен скриптами Сергея из [lesson7.md, строка 245 и далее](https://github.com/sirgray/specter-jen/blob/main/lesson7.md#L245).

| Задание | Фактический результат |
|---|---|
| Hours 5–6 — Retry & Exponential Backoff | `lesson7-parallel-demo` Build #1 SUCCESS; два моделируемых HTTP 503, паузы 1 и 2 секунды, успех на третьей попытке |
| Hours 7–8 — Multi-Stage Fallback | Тот же Job Build #2 SUCCESS; основной регион `us-east-1` неуспешен, резервный `us-west-2` успешен; `deployment.json` содержит `FAILOVER_SUCCESS` |
| Capstone — обычный сценарий | `lesson7-capstone-pipeline` Build #1 SUCCESS; три процесса, retry, `status.json` с `SUCCESS` |
| Capstone — аварийный сценарий | `emergency.json` сформирован с `FALLBACK_TRIGGERED`, `EMERGENCY`, `service_count: 3`, `build_result: FAILURE`; статус Jenkins Build #2 следует подтвердить итоговым отчётом |
| Extension Challenge — Audit Aggregator | `lesson7-audit-aggregator` Build #1 SUCCESS; 4 × SYNC SUCCESS, объединённый JSON из четырёх работников и MD5-проверка |

### Наши самостоятельные реализации

- [capstone_provision.groovy](capstone_provision.groovy) — самостоятельное решение Capstone, проверено на успешном сценарии и на формировании аварийного манифеста.
- [audit_aggregator_provision.groovy](audit_aggregator_provision.groovy) — самостоятельное решение дополнительного задания, проверено в Killercoda, Build #1 SUCCESS.
- [report.sh](report.sh) — итоговый отчёт для конкретной **новой** сессии, где `parallel-demo` Build #1 = retry, Build #2 = fallback, Capstone #1/#2 — два сценария, Audit #1 — аудит. Скрипт завершится ошибкой, если ожидаемый статус не подтверждается. Ещё требуется его непосредственный тест в Killercoda.

Запуск итогового отчёта:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lessons/main/lesson7/report.sh -o /tmp/lesson7-report.sh
bash /tmp/lesson7-report.sh
```

Важно: текущая папка `/ws/` отражает последнее состояние рабочей директории. Для долговременной отчётности нужно дополнительно архивировать артефакты по номерам сборок. Скрипты Hours 5–8 у Сергея перезаписывают один и тот же Job; сохранять их копии по отдельности полезно для воспроизводимости.
