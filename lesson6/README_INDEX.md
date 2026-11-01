# Lesson 6 — навигация

Главная инструкция: [README.md](README.md).

- [restore.sh](restore.sh) — восстановление трёх Jenkins Job из файлов **этого** репозитория.
- [report.sh](report.sh) — итоговый отчёт по трём заданиям; доступ к текущим workspace через /job/NAME/ws/.
- [HOMEWORK.md](HOMEWORK.md) — объяснение ошибки curl (3) и решения через `-g`.
- [LESSON_SUMMARY.md](LESSON_SUMMARY.md) — заметки о первоначальной практике 25 октября.

Повторная практика 1 ноября 2026: восстановление трёх заданий прошло успешно, `lesson6-artifact-demo` Build #1 SUCCESS и скачанный файл прошёл MD5, `lesson6-capstone-pipeline` Build #1 SUCCESS и `release.json` прочитан, финальная лабораторная создала корректный `manifest.json`. Финальная лабораторная также завершилась Build #1 `SUCCESS`. Обновлённый `report.sh` из нового репозитория успешно запущен и проверил все три задания. Новый `restore.sh` с исправленными URL ещё требует отдельной проверки в свежей сессии.
