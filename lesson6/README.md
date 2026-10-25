# Lesson 6 — Jenkins Artifacts & Validation Gates

Оригинальное задание Сергея: [lesson6.md](https://github.com/sirgray/specter-jen/blob/main/lesson6.md).

## Файлы

- [provision.groovy](provision.groovy) — Hours 1–2, генерация файлов в Workspace.
- [validation.groovy](validation.groovy) — Hours 3–4, проверки манифеста.
- [checksums.groovy](checksums.groovy) — Hours 7–8: MD5, ArtifactArchiver и fingerprints.
- [capstone_provision.groovy](capstone_provision.groovy) — Hours 9–10: Capstone.
- [lab_artifact_verifier.groovy](lab_artifact_verifier.groovy) — самостоятельная лабораторная на Bash.
- [restore.sh](restore.sh) — восстановление всех трёх Jenkins Job.
- [report.sh](report.sh) — единый отчёт по результатам трёх Job (исправлено `curl -g`).
- [HOMEWORK.md](HOMEWORK.md) — домашнее задание: разбор и исправление `curl: (3) bad range in URL`.

## Восстановление в новой Killercoda

Установка Jenkins (пока он отсутствует):

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/fast-setup.sh -o /tmp/jenkins-fast.sh
bash /tmp/jenkins-fast.sh
```

Когда Jenkins доступен (HTTP 200) и известен локальный пароль:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/restore.sh -o /tmp/lesson6-restore.sh
bash /tmp/lesson6-restore.sh
```

Скрипт **не запускает сборку автоматически** и не уничтожает текущую Job или историю сборок. Он восстанавливает `lesson6-artifact-demo` (конечная конфигурация Hours 7–8), `lesson6-capstone-pipeline` и `lab-artifact-verifier` без запуска сборок.

Для проверки из API:
```bash
PASS=$(cat /root/.jenkins-lesson5-fast/admin-password)
curl -fsS -u "admin:$PASS" http://localhost:8080/job/lesson6-artifact-demo/lastBuild/consoleText
```

**Важно:** примерная строка `"checksum_verified": true` не является криптографической проверкой SHA-256. Скачивание из `/ws/` относится к текущему Workspace, а не к архиву конкретной сборки.

## Результаты практики 25.10.2026

Build #1 с PRODUCTION — SUCCESS; Build #2 с STAGING — SUCCESS. ZIP с Workspace был скачан, проверен и распакован. В уроке использовались Crumb + cookies одной сессии для POST-вызовов.

## Практика 25 октября 2026 (продолжение)

Hours 7–8: Jenkins `SUCCESS`, `Archiving artifacts`, `Recording fingerprints`, архивированный `app-v1.bin` успешно проверен через `md5sum -c` после скачивания. Capstone: Build #1 `SUCCESS`, `release.json` получен через REST API. Для лабораторной скрипт исправлен на Bash из-за отсутствия `python3` внутри Jenkins; успешный повторный запуск пока не подтверждён.

## Итоговый отчёт

После восстановления Jenkins и выполнения сборок:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/report.sh -o /tmp/lesson6-report.sh
bash /tmp/lesson6-report.sh
```

Единый отчёт ранее успешно проверен в Killercoda после исправления флага `-g`. Файлы `report.sh` и `HOMEWORK.md` сохранены для повторного запуска и сдачи.
