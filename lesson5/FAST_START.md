# Быстрый запуск Jenkins Lesson 5 в чистой Killercoda

Этот способ **не устанавливает Suggested Plugins** и не требует проходить мастер настройки. Для создания и запуска учебного **Freestyle** Job специальные дополнительные плагины не нужны.

## Запуск одной командой

В **чистой** Killercoda:

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/fast-setup.sh -o /tmp/jenkins-lesson5-fast-setup.sh
bash /tmp/jenkins-lesson5-fast-setup.sh
```

Скрипт создаёт Docker volume `jenkins_home`, контейнер `my-jenkins` и учётную запись `admin` со случайным паролем. Защита CSRF **не отключается**, а анонимный административный доступ закрыт. Текущий контейнер, если он уже существует, **не удаляется**.

Пароль находится **только на хосте Killercoda** в `/root/.jenkins-lesson5-fast/admin-password`. Для просмотра:

```bash
cat /root/.jenkins-lesson5-fast/admin-password
```

Не отправляй пароль в чат и не сохраняй его в GitHub. Открой текущий порт **8080** через Killercoda и войди как `admin`.

## Получение Jenkins API token

В Jenkins открой **admin → Security → API Token → Add new Token**. Скопируй токен и введи:

```bash
read -rsp "Jenkins API token: " API_TOKEN; echo
export API_TOKEN
```

Проверка (не печатает секрет):

```bash
curl -fsS -u "admin:$API_TOKEN" http://localhost:8080/whoAmI/api/json \
  | python3 -c 'import json,sys; x=json.load(sys.stdin); print(x.get("authenticated"),x.get("name"))'
```

Ожидаем `True admin`.

## Восстановление Job Hours 3–4

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5/recover.sh -o /tmp/lesson5-recover.sh
bash /tmp/lesson5-recover.sh
```

После восстановления `lesson5-webhook-demo` используй тесты из [полной инструкции](FULL_KILLERCODA_GUIDE.md).

**Важно:** это ускорение применимо к отдельным Freestyle-лабораторным. Для старых Pipeline-заданий из Lesson 2 потребуются соответствующие плагины. В данном сценарии контейнер открыт через внешний порт Killercoda, поэтому не используй его с реальными секретами или как production Jenkins. Пересоздание сессии Killercoda уничтожит и контейнер, и volume. Скрипт ещё предстоит проверить на чистой сессии.
