# Lesson 1 — основы Jenkins: Freestyle и Pipeline

Источник: [задание Сергея](https://github.com/sirgray/specter-jen/blob/main/lesson1.md). Здесь собраны примеры из задания и наш ранее подготовленный Pipeline.

## Подготовка

Для учебной сессии Killercoda сначала установите Jenkins с авторизацией. Можно воспользоваться уже испытанным скриптом из Lesson 5 (он пока загружается из прежнего репозитория):

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/fast-setup.sh -o /tmp/jenkins-fast.sh
bash /tmp/jenkins-fast.sh
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/login
```

Открыть в Killercoda порт 8080, войти как `admin`. Пароль хранится **только в учебной среде** по пути `/root/.jenkins-lesson5-fast/admin-password`. Не публиковать пароль и API-токен в GitHub. Сценарий преподавателя без мастера настройки отключает CSRF; здесь CSRF оставляем включённой.

## 1. Freestyle — Hello World

В Jenkins выберите **New Item → Hello-World-Freestyle → Freestyle project**. В разделе **Build Steps → Execute shell** вставьте содержимое [freestyle-hello.sh](freestyle-hello.sh):

```bash
echo "Hello World from Jenkins!"
echo "Current date is: $(date)"
```

Нажмите **Save → Build Now → Console Output**. Ожидается `Finished: SUCCESS`.

## 2. Первый Pipeline

**New Item → My-First-Pipeline → Pipeline**. В разделе Pipeline выберите **Pipeline script** и вставьте код [My-First-Pipeline.Jenkinsfile](My-First-Pipeline.Jenkinsfile). Он содержит стадии **Compile → Test → Deploy**. Это учебная имитация: реального развёртывания приложения нет.

После **Build Now** убедитесь, что все три стадии выполнились и получено `Finished: SUCCESS`.

## 3. Pipeline из GitHub

В репозитории сохранён пример преподавателя [Git-Verification.Jenkinsfile](Git-Verification.Jenkinsfile): список файлов и тестовая команда. Также сохранён [наш Jenkinsfile](Jenkinsfile) с запуском [test.sh](test.sh).

Создайте Pipeline, в настройках выберите **Pipeline script from SCM**, **Git**, Repository URL:

```text
https://github.com/Oboltus01/jenkins-lessons.git
```

Branch: `*/main`. В поле **Script Path** по очереди можно указать:

- `lesson1/Git-Verification.Jenkinsfile` — проверка файлов в workspace;
- `lesson1/Jenkinsfile` — выполнение `lesson1/test.sh`.

Для второго варианта команда запускается внутри `dir('lesson1')`, так как исходники теперь находятся в папке урока, а не в корне репозитория.

## 4. Домашняя работа: версия приложения

Учитель предлагает добавить файл `version.txt` с содержимым `v1.0.0` и вывести его командой `sh 'cat version.txt'`.

Файлы: [version.txt](version.txt) и [Version-Check.Jenkinsfile](Version-Check.Jenkinsfile). Создайте ещё один Pipeline **из Git SCM** и укажите **Script Path** `lesson1/Version-Check.Jenkinsfile`.

Скрипт переходит в `lesson1`, проверяет, что файл не пуст, и выводит версию. Ожидаемая строка в логе:

```text
v1.0.0
```

## Проверка и статус

Проверьте четыре задания: Freestyle, My-First-Pipeline, Git-Verification и Version-Check; при необходимости наш отдельный Git Pipeline. Для каждого сохраните `Console Output` с `Finished: SUCCESS`.

**Статус:** файлы сверены с текстом первого урока и исправлены пути для нового репозитория. Сквозная проверка на чистой Killercoda ещё не проводилась. Примеры преподавателя могут быть сокращёнными — мы добавили объяснения и разделили их по заданиям.
