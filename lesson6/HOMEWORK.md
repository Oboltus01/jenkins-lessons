# Lesson 6 — домашнее задание: исправление curl (3)

Дата практики: 25.10.2026. Сценарий: единый отчёт по трём Jenkins Job через REST API.

## Ошибка

При запросе `/job/lesson6-artifact-demo/lastBuild/api/json?tree=artifacts[fileName]` команда `curl` вернула:

```text
curl: (3) bad range in URL position 83
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

Причина: клиент `curl` обрабатывает квадратные скобки URL как синтаксис URL globbing, а не как часть Jenkins API `tree`. Следом Python попытался разобрать пустой ответ как JSON.

## Исправление

Было:

```bash
curl -fsS -u "admin:$PASS" "$BASE$1"
```

Стало:

```bash
curl -gfsS -u "admin:$PASS" "$BASE$1"
```

Опция `-g` (`--globoff`) отключает URL globbing. Не следует убирать `-f`: он нужен для сообщения об HTTP-ошибке.

## Проверка

После исправления единый отчёт был успешно сформирован:

- Capstone Hours 9–10: Build #1 SUCCESS, `payment-gateway`, `v4.0.0`, `verified: true`.
- MD5 Hours 7–8: Build #1 SUCCESS, MD5 проверен, `Archiving artifacts`, `Recording fingerprints`, доступны `app-v1.bin` и `app-v1.bin.md5`.
- Lab Artifact Verifier: Build #2 SUCCESS, `auth-module`, `101`, `PASS`; `LAB-TEARDOWN` выполнен.

После установки и восстановления Jenkins запуск отчёта:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/report.sh -o /tmp/lesson6-report.sh
bash /tmp/lesson6-report.sh
```

Скрипт читает результаты существующих сборок. Он не создаёт и не запускает сборки. Требуется хотя бы одна завершённая сборка каждого Job.
