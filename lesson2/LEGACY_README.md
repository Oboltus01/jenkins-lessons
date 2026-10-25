# Jenkins Lesson 2 — восстановление Killercoda

Этот репозиторий хранит Jenkins pipeline-файлы и автоматические скрипты восстановления учебной среды Killercoda.

## Рекомендуемый запуск: Lesson 5 (Jenkins с паролем)

В **новой сессии Killercoda** выполни одну команду:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/33719f55aa21fb0caf15417e2f1b9c060203290a/lesson5/start-all.sh \
  -o /tmp/jenkins-start.sh && bash /tmp/jenkins-start.sh
```

Скрипт `lesson5/start-all.sh` предложит ввести выбранный пароль администратора (не менее 12 символов), поднимет контейнер `my-jenkins`, проверит пользователя `admin`, настроит CSRF для HTTPS-прокси и восстановит **два задания**: `lesson5-webhook-demo` (финальная версия Hours 5–6) и `lab-webhook-receiver` (домашнее задание). При повторном запуске в этой же сессии пароль берётся из локального файла; после сброса Killercoda тот же пароль нужно ввести заново. **Пароль не хранится в GitHub.**

Открой Killercoda **Traffic / Ports → 8080** и войди под `admin` с выбранным паролем.

Подробности, пример JSON для Build with Parameters и восстановление: [lesson5/README.md](lesson5/README.md).

---

> Скрипты предназначены только для учебной временной среды, не для production. Старый запуск Lesson 2, описанный ниже, отключает CSRF; новый `lesson5/start-all.sh` оставляет CSRF включённым.

## Старый способ запуска: Lesson 2

В новой Killercoda-сессии достаточно выполнить **одну команду**:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/killercoda.sh | bash
```

После этого:

1. `killercoda.sh` клонирует репозиторий в `~/jenkins-lesson-2` или обновляет его, если он уже существует.
2. Автоматически запускает `bootstrap-killercoda.sh`.
3. Jenkins запускается в Docker.
4. В Jenkins устанавливается Docker-клиент.
5. Устанавливаются плагины Pipeline, Git и Docker Pipeline.
6. Создаются четыре Jenkins job, использующие Jenkinsfile из этого репозитория.

После сообщения `Done. Open port 8080 in Killercoda.` открой порт **8080**. Задания уже будут видны в Jenkins.

### Альтернативный запуск

Если репозиторий уже клонирован:

```bash
cd ~/jenkins-lesson-2
bash bootstrap-killercoda.sh
```

Или вручную с нуля:

```bash
git clone https://github.com/Oboltus01/jenkins-lesson-2.git
cd jenkins-lesson-2
bash bootstrap-killercoda.sh
```

## Задания Jenkins

| Job | Jenkinsfile | Назначение |
|---|---|---|
| `Git-Pipeline` | `Jenkinsfile` | Выполняет `test.sh` и выводит приветствие. |
| `docker-multi-agent` | `jenkinsfiles/docker-multi-agent.Jenkinsfile` | Проверяет Node.js/npm и Python/pip в Docker-агентах. |
| `docker-build-job` | `jenkinsfiles/docker-build.Jenkinsfile` | Собирает образ `my-web-app:1` и тестирует контейнер. |
| `practice-lab-4` | `jenkinsfiles/practice-lab-4.Jenkinsfile` | Создаёт и архивирует артефакт `build.log`. |

Для запуска сборки нажми зелёный треугольник справа от нужного job. Если запустить несколько job подряд, Jenkins поместит их в очередь сборок и распределит по доступным исполнителям.

## Проверка из терминала Killercoda

Проверить, что Jenkins видит Docker:

```bash
docker exec jenkins docker ps
```

Проверить результаты всех job через Jenkins API:

```bash
curl -sg 'http://localhost:8080/api/json?tree=jobs[name,color,lastBuild[number,result,duration]]' | python3 -m json.tool
```

У каждого job ожидается:

```text
"result": "SUCCESS"
```

Проверить артефакт `practice-lab-4`:

```bash
docker exec jenkins cat /var/jenkins_home/jobs/practice-lab-4/builds/1/archive/build.log
```

Ожидаемый результат:

```text
Build completed successfully
```

## Ручное восстановление — для обучения

Автоматический скрипт выполняет следующие основные действия:

```bash
docker run -d --name jenkins --restart always -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true" \
  jenkins/jenkins:lts-jdk17

docker exec -u 0 jenkins sh -c 'apt-get update && apt-get install -y docker.io && chmod 666 /var/run/docker.sock'

docker exec jenkins jenkins-plugin-cli --plugins workflow-aggregator git docker-workflow

docker restart jenkins
```

Job-конфигурации создаются скриптом `bootstrap-killercoda.sh`, а их pipeline-код Jenkins берёт из GitHub. Поэтому после следующего сброса Killercoda вручную создавать jobs и заполнять поля SCM не нужно.
