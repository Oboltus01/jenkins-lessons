# Jenkins Lesson 5 — полная последовательность с чистой Killercoda

Практика от 18 октября 2026. [Оригинал Сергея](https://github.com/sirgray/specter-jen/blob/main/lesson5.md).

**Цель:** развернуть Jenkins, создать Job `lesson5-webhook-demo`, проверить получение JSON, обновление Groovy и маршрутизацию событий `release` / `push` / `ping`.

## 1. Запуск Jenkins в чистой Killercoda

В сценарии Docker открой терминал:

```bash
docker ps -a
docker volume create jenkins_home
docker run -d --name my-jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts-jdk17
```

Мы используем стандартный мастер начальной настройки, не отключая защиту Jenkins. Дождись запуска:

```bash
for i in {1..60}; do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login)
  echo "Attempt $i: HTTP $code"
  [ "$code" = 200 ] && break
  sleep 5
done
docker ps --filter name=my-jenkins
```

Открой в Killercoda порт **8080**. Получи одноразовый пароль мастера:

```bash
docker exec my-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

В браузере: **Unlock Jenkins → Install suggested plugins → Create First Admin User**, username `admin`, свой надёжный пароль. Дождись Dashboard. Никогда не публикуй пароль или токен.

## 2. Настройка API-токена

В веб-интерфейсе: **admin → Security → API Token → Add new Token → Generate**. Назови `StudentLabToken`. Скопируй токен.

```bash
read -rsp "Jenkins API token: " API_TOKEN; echo
export API_TOKEN
curl -fsS -u "admin:$API_TOKEN" http://localhost:8080/whoAmI/api/json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("Authenticated:",d.get("authenticated"),"User:",d.get("name"))'
```

Ожидаем `Authenticated: True User: admin`. HTTP 200 без этого поля не доказывает вход. Если 401/403, проверь токен, а не отключай безопасность. Для API-токена CSRF crumb в обычной настройке Jenkins не нужен.

## 3. Скачивание Groovy из нашего репозитория

```bash
mkdir -p ~/jenkins-lesson5
cd ~/jenkins-lesson5
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/provision.groovy -o provision.groovy
```

Этот файл — **итоговая версия Hours 3–4**. Для воспроизведения урока с самого начала сделай сначала раздел 4, затем 5. Для быстрого восстановления достаточно раздела 5.

## 4. Hours 1–2: создаём Freestyle Job, принимающий JSON

```bash
cat > hours1-2.groovy <<'GROOVY'
import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.Shell

def j = Jenkins.get()
def name = 'lesson5-webhook-demo'
def job = j.getItem(name) ?: j.createProject(FreeStyleProject, name)
def param = new StringParameterDefinition(
    'PAYLOAD_JSON', '{"event":"default"}', 'Raw JSON payload'
)
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(param))

def shellScript = '''#!/usr/bin/env bash
set -euo pipefail
echo "HOURS 1-2: WEBHOOK ENDPOINT INGESTION"
echo "Received Raw Payload:"
echo "$PAYLOAD_JSON"
'''
job.getBuildersList().clear()
job.getBuildersList().add(new Shell(shellScript))
job.save()
println 'LESSON5_HOURS1_2_PROVISIONED'
GROOVY

curl -fsS --fail-with-body -u "admin:$API_TOKEN" \
  -X POST http://localhost:8080/scriptText \
  --data-urlencode 'script@hours1-2.groovy'
```

Ожидаем `LESSON5_HOURS1_2_PROVISIONED`. Тест:

```bash
curl -fsS --fail-with-body -u "admin:$API_TOKEN" -X POST \
  http://localhost:8080/job/lesson5-webhook-demo/buildWithParameters \
  --data-urlencode 'PAYLOAD_JSON={"event":"push","ref":"refs/heads/main","actor":"devops-admin"}'
```

Сборка запускается асинхронно. Не полагайся на `sleep 3` и `lastBuild`: можно случайно увидеть лог старой сборки. Смотри номера и завершение в разделе 6.

## 5. Hours 3–4: меняем Shell в существующем Job

```bash
curl -fsS --fail-with-body -u "admin:$API_TOKEN" \
  -X POST http://localhost:8080/scriptText \
  --data-urlencode 'script@provision.groovy'
```

Ожидаем `LESSON5_HOURS3_4_PROVISIONED`.

Смысл ключевых команд Groovy:

```groovy
job.getBuildersList().clear()
job.getBuildersList().add(new Shell(parsingShellScript))
job.save()
```

Они заменяют старый Shell-шаг в том же Job. Финальная версия разбирает поля `event`, `repo`, `action`, выбирает ветки `release`, `push`, `else`. Учебный парсер `grep/cut` не подходит для произвольного JSON; в реальных проектах используй `jq`.

## 6. Тестируем release, push и ping с ожиданием КОНКРЕТНОЙ сборки

Вставь весь блок в терминал:

```bash
JOB=http://localhost:8080/job/lesson5-webhook-demo

run_payload() {
  local payload="$1" old next state i
  old=$(curl -fsS -u "admin:$API_TOKEN" "$JOB/api/json?tree=lastBuild[number]" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("lastBuild") or {}).get("number",0))')
  next=$((old + 1))

  curl -fsS --fail-with-body -u "admin:$API_TOKEN" -X POST \
    "$JOB/buildWithParameters" --data-urlencode "PAYLOAD_JSON=$payload"

  for i in {1..60}; do
    state=$(curl -fsS -u "admin:$API_TOKEN" "$JOB/$next/api/json?tree=result" 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result") or "RUNNING")' 2>/dev/null || true)
    if [ "$state" = SUCCESS ] || [ "$state" = FAILURE ] || [ "$state" = ABORTED ]; then
      echo "Build #$next: $state"
      curl -fsS -u "admin:$API_TOKEN" "$JOB/$next/consoleText"
      [ "$state" = SUCCESS ]
      return
    fi
    sleep 2
  done
  echo "Timed out waiting for build #$next" >&2
  return 1
}

run_payload '{"event":"release","repo":"org/core-service","action":"published"}'
run_payload '{"event":"push","repo":"org/core-service","action":"synchronize"}'
run_payload '{"event":"ping","repo":"org/core-service","action":"created"}'
```

Ожидаем:

| Событие | Вывод | Итог |
|---|---|---|
| release | Production release detected | SUCCESS |
| push | Source code update detected | SUCCESS |
| ping | requires no secondary tasks | SUCCESS |

История сборок:

```bash
curl -gsS -u "admin:$API_TOKEN" \
  'http://localhost:8080/job/lesson5-webhook-demo/api/json?tree=builds[number,result]' \
  | python3 -m json.tool
```

## 7. Наш фактический результат 18 октября

Мы проверили пять сборок, все **SUCCESS**: #1 и #2 — приём JSON, #3 — release, #4 — push, #5 — ping. В новой сессии Killercoda номера снова начнутся с #1.

Важное различие: `buildWithParameters` здесь **имитирует** получение webhook; внешний endpoint GitHub не настраивался. Ветки `release` и `push` пока выводят сообщения, не делают реального deploy и не запускают тесты.

## 8. Самое быстрое восстановление после сброса Killercoda

Повтори разделы **1–2** (Jenkins + пользователь + API token), после чего можешь пропустить Hours 1–2 и сразу восстановить итоговый Job:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/recover.sh -o /tmp/lesson5-recover.sh
bash /tmp/lesson5-recover.sh
```

`recover.sh` ожидает переменную `API_TOKEN`. Это **не** автоматическая установка администратора/токена. После восстановления проверь Job командами раздела 6.

### Типовые ошибки

- HTTP 503 — Jenkins ещё запускается.
- Bash показывает приглашение `>` — не завершён heredoc: Ctrl+C, вставить полный блок до строки `GROOVY`.
- HTTP 401/403 — проблема авторизации; проверь `whoAmI`.
- Для запросов вида `?tree=jobs[name,color]` используй `curl -g`, иначе curl трактует квадратные скобки как glob.
- `lastBuild` показал старый JSON — дождись конкретного номера новой сборки.
