# Jenkins Lesson 5 — Webhook JSON Parsing (18 October 2026)

Source: [Sergey's lesson5.md](https://github.com/sirgray/specter-jen/blob/main/lesson5.md).

This directory saves the **Hours 3–4 final job configuration** and a standalone recovery script. It does not modify the older Lesson 2 bootstrap or Jenkins jobs.

## What we completed

- Freestyle job: `lesson5-webhook-demo`
- Parameter: `PAYLOAD_JSON`
- Groovy provisioning using administrator API `POST /scriptText`
- Hours 1–2: receive and print a JSON payload
- Hours 3–4: extract `event`, `repo`, `action` and select a shell branch
- Verified 5 successful builds: two ingestion tests, then `release`, `push`, and `ping`

Actions in the shell script are **messages only**: it does not actually deploy software or run unit tests. `buildWithParameters` is a Jenkins API call used to simulate a webhook; this example does not register an external webhook receiver. The grep/cut parser works for the compact sample format, but is not a general JSON parser.

## Quick start — new Killercoda session (recommended)

Run this command in Killercoda's terminal:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/33719f55aa21fb0caf15417e2f1b9c060203290a/lesson5/start-all.sh \
  -o /tmp/jenkins-start.sh && bash /tmp/jenkins-start.sh
```

- On a fresh session, choose and enter a password (at least 12 characters) when prompted. Input is hidden.
- Open **Traffic / Ports → 8080**; username is `admin`, password is the one you entered.
- The script initializes Jenkins as `my-jenkins`, keeps CSRF enabled (with client IP excluded for Killercoda's HTTPS reverse proxy), and creates or updates both `lesson5-webhook-demo` (Hours 5–6) and `lab-webhook-receiver` (homework).
- In the same session, rerunning the command reuses the local password file and existing container; it does not delete the job. In a new Killercoda session, enter the same chosen password again.
- Passwords are never committed to GitHub; they are stored only in temporary Killercoda files. This is for a temporary training environment, not production.

After login, open `lesson5-webhook-demo` → **Build with Parameters** and use:

```json
{"event":"release","repo":"Oboltus01/jenkins-lesson-2","action":"published"}
```

Then click **Build** and inspect **Console Output** for `Finished: SUCCESS`.

### Standalone recovery (when Jenkins is already installed)

```bash
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/6146c1829e41aabfbfa99ca4fb8e3775c0b26563/lesson5/recover.sh -o /tmp/jenkins-recover.sh
bash /tmp/jenkins-recover.sh
```

This uses the existing temporary admin password and CSRF token for authentication; a separately created API token is not required in this lab setup.

## Send test data

```bash
JOB=http://localhost:8080/job/lesson5-webhook-demo
for payload in \
  '{"event":"release","repo":"org/core-service","action":"published"}' \
  '{"event":"push","repo":"org/core-service","action":"synchronize"}' \
  '{"event":"ping","repo":"org/core-service","action":"created"}'
do
  curl -fsS -u "admin:$API_TOKEN" -X POST "$JOB/buildWithParameters" \
    --data-urlencode "PAYLOAD_JSON=$payload"
done
```

Check build numbers and completion before requesting logs (queueing is asynchronous):

```bash
curl -gsS -u "admin:$API_TOKEN" \
  'http://localhost:8080/job/lesson5-webhook-demo/api/json?tree=builds[number,result,building]' \
  | python3 -m json.tool
```

Read a **specific** build number `N` using `$JOB/N/consoleText`. Avoid relying on `sleep 3` followed by `lastBuild`, because it can show an earlier run.

## Notes

- `provision.groovy` is re-runnable and updates the same job.
- The old `jenkins-lesson-2` recovery scripts are left untouched.
- For a real Jenkins installation, keep authentication and CSRF protection enabled.


## Verified continuation: Hours 5–6 and lab homework (25 October 2026)

After the Hours 3–4 job has been restored, apply the verified Groovy scripts in order:

- [security-hours5-6.groovy](security-hours5-6.groovy) — updates `lesson5-webhook-demo`, adds `AUTH_TOKEN` and tests token validation
- [lab-webhook-receiver.groovy](lab-webhook-receiver.groovy) — creates a separate Freestyle job with `SECRET_KEY` and `EVENT_PAYLOAD`

Run from a fresh Killercoda shell **after** `start-all.sh`. Commands below reuse the locally stored administrator password and use the same session cookie as the CSRF crumb:

```bash
PASS=$(cat /root/.jenkins-lesson5-fast/admin-password)
COOKIE=$(mktemp)
trap 'rm -f "$COOKIE"' EXIT
CRUMB=$(curl -fsS -u "admin:$PASS" -c "$COOKIE" -b "$COOKIE" \
  http://localhost:8080/crumbIssuer/api/json |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["crumb"])')

BASE=https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5
for file in security-hours5-6.groovy lab-webhook-receiver.groovy; do
  curl -fsSL "$BASE/$file" -o "/tmp/$file"
  curl -fsS -u "admin:$PASS" -b "$COOKIE" -c "$COOKIE" \
    -H "Jenkins-Crumb: $CRUMB" \
    --data-urlencode "script@/tmp/$file" \
    http://localhost:8080/scriptText
done
```

**Observed tests (one Killercoda session):** `lesson5-webhook-demo` builds #1 push SUCCESS, #2 release SUCCESS, #3 invalid token FAILURE (expected), #4 failed due to absent python3 inside Jenkins image, #5 corrected grep/cut SUCCESS. `lab-webhook-receiver` build #1 invalid secret FAILURE (expected); build #2 valid secret SUCCESS, output `Processing action 'deploy' for component 'backend'`, and cleanup executed.

These are **demonstration** values in a training lab, not production secrets. The scripts use simplified JSON extraction with grep/cut and do not implement a public webhook endpoint. The current fast-start launcher applies both final Groovy configurations automatically. The continuation commands above are optional for manual practice.
