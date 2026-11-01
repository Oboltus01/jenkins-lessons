# Lesson 6 — Jenkins Artifacts & Validation Gates

Оригинал Сергея: [lesson6.md](https://github.com/sirgray/specter-jen/blob/main/lesson6.md). Наши исходники и результаты сохранены в этом репозитории.

## Файлы

- [provision.groovy](provision.groovy) — Hours 1–2, генерация файлов в Workspace.
- [validation.groovy](validation.groovy) — Hours 3–4, проверки манифеста.
- [checksums.groovy](checksums.groovy) — Hours 7–8, MD5, Archive Artifacts, fingerprints.
- [capstone_provision.groovy](capstone_provision.groovy) — Hours 9–10, `release.json`.
- [lab_artifact_verifier.groovy](lab_artifact_verifier.groovy) — финальная лабораторная.
- [restore.sh](restore.sh) — восстановление трёх Job.
- [report.sh](report.sh) — итоговый отчёт (включает исправление `curl -g`).
- [HOMEWORK.md](HOMEWORK.md) — разбор ошибки `curl: (3) bad range in URL`.

## Восстановление в новой Killercoda

Сначала создайте Jenkins с аутентификацией и включённой CSRF-защитой:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lessons/main/lesson5/fast-setup.sh -o /tmp/jenkins-fast.sh
bash /tmp/jenkins-fast.sh
```

Убедитесь, что Jenkins отвечает: `curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/login` → `HTTP 200`.

Восстановление заданий:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lessons/main/lesson6/restore.sh -o /tmp/lesson6-restore.sh
bash /tmp/lesson6-restore.sh
```

Ожидаются сообщения `LESSON6_HOURS1_2_PROVISIONED`, `LESSON6_HOURS3_4_PROVISIONED`, `LESSON6_HOURS7_8_PROVISIONED`, `LESSON6_CAPSTONE_PROVISIONED`, `LAB_ARTIFACT_VERIFIER_PROVISIONED`.

Создаются или обновляются три Job:

1. `lesson6-artifact-demo` — в конечной конфигурации Hours 7–8.
2. `lesson6-capstone-pipeline` — `APP_NAME` и `RELEASE_VERSION`.
3. `lab-artifact-verifier` — `MODULE_NAME` и `BUILD_NUMBER_ID`.

**Важно:** `restore.sh` только восстанавливает конфигурацию, не запускает новые сборки. При повторном развёртывании он заменяет builders и параметры этих трёх Jobs, но не очищает историю сборок. Не используйте в production.

## Проверка сборок

В учебной практике для POST на `/buildWithParameters` использовали **Basic Auth + CSRF Crumb + cookie той же сессии**. Пример проверочного GET:

```bash
PASS=$(cat /root/.jenkins-lesson5-fast/admin-password)
curl -gfsS -u "admin:$PASS" \
  'http://localhost:8080/job/lesson6-artifact-demo/lastBuild/api/json?tree=number,building,result,artifacts[fileName]' \
  | python3 -m json.tool
```

### MD5 и архив конкретной сборки

Для `lesson6-artifact-demo` Build #1 архивированные файлы расположены по адресам:

```text
/job/lesson6-artifact-demo/1/artifact/dist/packages/app-v1.bin
/job/lesson6-artifact-demo/1/artifact/dist/packages/app-v1.bin.md5
```

При повторе 01.11.2026 скачанные файлы прошли `md5sum -c` с результатом `app-v1.bin: OK`. MD5 используется только как упражнение на целостность, не для криптографической защиты.

### Capstone и финальная лабораторная

Получение файлов **текущей рабочей директории** Jenkins:

```bash
curl -fsS -u "admin:$PASS" \
  http://localhost:8080/job/lesson6-capstone-pipeline/ws/dist/release.json \
  | python3 -m json.tool

curl -fsS -u "admin:$PASS" \
  http://localhost:8080/job/lab-artifact-verifier/ws/build_out/manifest.json \
  | python3 -m json.tool
```

Неправильный путь `/job/lesson6-capstone-pipeline/lastBuild/ws/dist/release.json` дал HTTP 404. **Правильный путь к workspace — `/job/NAME/ws/...`.** Workspace может измениться после следующей сборки или очистки. Для неизменяемых артефактов конкретной сборки нужно отдельно настроить архивирование; у Capstone оно пока не настроено.

В текущем повторении Capstone Build #1 вернул `SUCCESS` и JSON:

```json
{"app":"payment-gateway","version":"v4.0.0","verified":true}
```

Финальная лабораторная вернула `manifest.json`:

```json
{"module":"auth-module","build_id":"101","status":"PASS"}
```

Это подтверждает создание файла; отдельный статус последней сборки в показанном выводе ещё не подтверждён.

## Единый итоговый отчёт

Запускайте **после сборок всех трёх Job**:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lessons/main/lesson6/report.sh -o /tmp/lesson6-report.sh
bash /tmp/lesson6-report.sh
```

Отчёт показывает статус каждого Job, JSON-манифесты и архивированные файлы. Исправление `curl -g` описано в [HOMEWORK.md](HOMEWORK.md). Скрипт завершится с ошибкой, если сборка не получила `SUCCESS` или если нужные файлы недоступны.

## Статус проверок

- 25.10.2026: практика и итоговый отчёт были проверены в Killercoda.
- 01.11.2026: восстановление всех трёх Job прошло успешно; для artifact-demo проверены SUCCESS, архив и MD5; для Capstone проверены SUCCESS и JSON; финальная лабораторная сформировала правильный JSON.
- Обновлённые в GitHub 01.11.2026 скрипты нужно проверить отдельно в Killercoda, особенно итоговый отчёт.
