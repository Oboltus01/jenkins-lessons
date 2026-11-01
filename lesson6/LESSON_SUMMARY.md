# Lesson 6 — Jenkins Artifacts и Validation Gates

**Занятие курса:** урок 12, 25 октября 2026 года.  
**Преподаватель:** Сергей.  
**Оригинал:** [lesson6.md](https://github.com/sirgray/specter-jen/blob/main/lesson6.md).

## Что выполнено в Killercoda

**Hours 1–2: Workspace Artifact Generation.** Groovy создал Freestyle Job `lesson6-artifact-demo` с параметром `BUILD_ENV`. Build #1 с `BUILD_ENV=PRODUCTION` завершился `SUCCESS`. Созданы `output/build_manifest.json` и `output/reports/execution.log`.

**Hours 3–4: Artifact Integrity & Failure Gates.** Обновили тот же Job скриптом валидации. Build #2 с `BUILD_ENV=STAGING` завершился `SUCCESS`. Проверены существование и ненулевой размер манифеста, а также наличие строки `"status": "COMPLETED"`. Выполнился обработчик `trap teardown EXIT`.

**Remote Inspection через REST API.** Скачали `output.zip` по маршруту `/ws/output/*zip*/output.zip`, проверили `unzip -t`, распаковали архив и прочитали `build_manifest.json`.

## Полезные команды

```bash
# Просмотр журнала сборки #2
curl -fsS -u "admin:$PASS" \
  http://localhost:8080/job/lesson6-artifact-demo/2/consoleText

# Скачать файлы текущего Workspace в ZIP
curl -fsS -u "admin:$PASS" \
  'http://localhost:8080/job/lesson6-artifact-demo/ws/output/*zip*/output.zip' \
  -o output.zip
unzip -t output.zip
unzip -oq output.zip
python3 -m json.tool output/build_manifest.json
```

## Технические замечания

- В учебной Killercoda с паролем `admin` для POST на `/scriptText` понадобились **CSRF Crumb и cookie одной сессии**; первый вариант без cookie возвращал HTTP 403.
- `checksum_verified: true` задан в примере статически — SHA-256 на практике не вычислялся.
- URL `/ws/` показывает **текущий Workspace**; это не архив артефактов конкретной сборки.
- Временные пароли и токены **не добавлять в Git**.

## Обновление 01.11.2026

Практика восстановлена через `restore.sh` в чистой Killercoda: все три Job появились. `lesson6-artifact-demo` Build #1 SUCCESS, файлы архива получены и проверены через `md5sum -c` (`app-v1.bin: OK`). `lesson6-capstone-pipeline` Build #1 SUCCESS, `release.json` прочитан через `/job/lesson6-capstone-pipeline/ws/dist/release.json`. Финальный Job сформировал правильный `build_out/manifest.json` с `status: PASS`; отдельная проверка статуса сборки ещё не показана.

**Важно:** новый путь к текущему Workspace — `/job/NAME/ws/...`, а не `/job/NAME/lastBuild/ws/...`. Для артефактов определённой сборки используйте `/job/NAME/BUILD_NUMBER/artifact/...`.

## Следующие улучшения

Проверить обновлённые скрипты из нового репозитория на следующем запуске Killercoda, автоматизировать сборки в отдельном тестовом сценарии и при необходимости добавить архивирование `release.json`.
