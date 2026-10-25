#!/usr/bin/env bash
set -euo pipefail

# Isolated temporary Killercoda lab. Not suitable for exposed/production Jenkins.
REPO_RAW="https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/main/lesson5"
JOB="lesson5-webhook-demo"

if ! docker ps --format '{{.Names}}' | grep -qx my-jenkins; then
  if docker ps -a --format '{{.Names}}' | grep -qx my-jenkins; then
    docker start my-jenkins
  else
    docker run -d --name my-jenkins -p 8080:8080 -p 50000:50000 \
      -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
      jenkins/jenkins:lts-jdk17
  fi
fi

echo "Waiting for Jenkins..."
ready=false
for i in $(seq 1 90); do
  if [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/login)" = 200 ]; then
    ready=true
    break
  fi
  sleep 3
done
if [ "$ready" != true ]; then
  echo "Jenkins did not become ready" >&2
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$REPO_RAW/provision.groovy" -o "$tmp"

if [ -n "${API_TOKEN:-}" ]; then
  curl -fsS -u "admin:$API_TOKEN" -X POST \
    http://localhost:8080/scriptText --data-urlencode "script@$tmp"
else
  PASS_FILE=/root/.jenkins-lesson5-fast/admin-password
  [ -s "$PASS_FILE" ] || { echo "No API_TOKEN or lab admin password found." >&2; exit 1; }
  COOKIE=$(mktemp)
  trap 'rm -f "$tmp" "$COOKIE"' EXIT
  ADMIN_PASS=$(cat "$PASS_FILE")
  CRUMB=$(curl -fsS -u "admin:$ADMIN_PASS" -c "$COOKIE" -b "$COOKIE" \
    http://localhost:8080/crumbIssuer/api/json | python3 -c \
    'import json,sys; print(json.load(sys.stdin)["crumb"])')
  curl -fsS -u "admin:$ADMIN_PASS" \
    -b "$COOKIE" -c "$COOKIE" -H "Jenkins-Crumb: $CRUMB" \
    -X POST http://localhost:8080/scriptText --data-urlencode "script@$tmp"
fi
# Verify that Groovy provisioning created the expected job.
CHECK_PASS="${API_TOKEN:-}"
if [ -z "$CHECK_PASS" ]; then CHECK_PASS=$(cat /root/.jenkins-lesson5-fast/admin-password); fi
if ! curl -fsS -u "admin:$CHECK_PASS" "http://localhost:8080/job/$JOB/api/json" >/dev/null; then
  echo "Job verification failed: $JOB" >&2
  exit 1
fi
echo "Provisioned and verified $JOB"
