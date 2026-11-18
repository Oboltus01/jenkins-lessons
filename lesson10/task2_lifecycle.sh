#!/usr/bin/env bash
set -euo pipefail
BASE=http://localhost:8080
: "${JENKINS_USER:?Export JENKINS_USER}"
: "${JENKINS_PASS:?Export JENKINS_PASS}"
COOKIE=$(mktemp)
GROOVY=$(mktemp)
trap 'rm -f "$COOKIE" "$GROOVY"' EXIT
auth=(-u "$JENKINS_USER:$JENKINS_PASS")
crumb_json=$(curl -fsS "${auth[@]}" -c "$COOKIE" -b "$COOKIE" "$BASE/crumbIssuer/api/json")
CRUMB=$(printf '%s' "$crumb_json" | sed -n 's/.*"crumb":"\([^"]*\)".*/\1/p')
[ -n "$CRUMB" ] || { echo "Unable to get Jenkins crumb" >&2; exit 1; }
post_groovy() {
  curl -fsS "${auth[@]}" -b "$COOKIE" -H "Jenkins-Crumb: $CRUMB" --data-urlencode "script@$GROOVY" "$BASE/scriptText"
}

cat > "$GROOVY" <<'GROOVY_CODE'
import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.Shell
import hudson.tasks.ArtifactArchiver

def j = Jenkins.get()
def name = 'lab-runner-check'
def job = j.getItemByFullName(name, FreeStyleProject)
if (job == null) {
  job = j.createProject(FreeStyleProject, name)
  println "[CREATE] ${name}"
} else {
  println "[UPDATE] ${name}"
}
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(new StringParameterDefinition('TOKEN', '', 'Tracking token')))
job.getBuildersList().clear()
job.getBuildersList().add(new Shell('''#!/bin/sh
set -eu
sleep 2
printf 'TOKEN=%s\n' "$TOKEN" > token.out
'''))
job.getPublishersList().clear()
def a = new ArtifactArchiver('token.out')
a.setOnlyIfSuccessful(true)
job.getPublishersList().add(a)
job.save()
println '[SUCCESS] Job configured'
GROOVY_CODE

echo '=== TASK 2: JOB PROVISIONING ==='
post_groovy
TOKEN="TOK-$(date +%s)"
echo "TOKEN: $TOKEN"
headers=$(mktemp)
trap 'rm -f "$COOKIE" "$GROOVY" "$headers"' EXIT
curl -fsS "${auth[@]}" -b "$COOKIE" -H "Jenkins-Crumb: $CRUMB" -D "$headers" -o /dev/null --data-urlencode "TOKEN=$TOKEN" "$BASE/job/lab-runner-check/buildWithParameters?delay=0sec"
QUEUE_URL=$(grep -i '^Location:' "$headers" | awk '{print $2}' | tr -d '\r\n')
[ -n "$QUEUE_URL" ] || { echo 'No queue Location header' >&2; exit 1; }
echo "Queue: $QUEUE_URL"
BUILD_NUM=''
for i in $(seq 1 60); do
  response=$(curl -sg "${auth[@]}" "${QUEUE_URL%/}/api/json?tree=executable[number]" || true)
  BUILD_NUM=$(printf '%s' "$response" | sed -n 's/.*"number":\([0-9]*\).*/\1/p')
  [ -n "$BUILD_NUM" ] && break
  sleep 1
done
[ -n "$BUILD_NUM" ] || { echo 'Queue item was evicted or no build assigned; cannot safely use lastBuild' >&2; exit 1; }
echo "Build number: $BUILD_NUM"
RESULT=''
for i in $(seq 1 90); do
  response=$(curl -fsg "${auth[@]}" "$BASE/job/lab-runner-check/$BUILD_NUM/api/json?tree=building,result")
  if printf '%s' "$response" | grep -q '"building":false'; then
    RESULT=$(printf '%s' "$response" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
    break
  fi
  sleep 1
done
[ "$RESULT" = SUCCESS ] || { echo "Build failed or timed out: $RESULT" >&2; exit 1; }
curl -fsS "${auth[@]}" -o token.out "$BASE/job/lab-runner-check/$BUILD_NUM/artifact/token.out"
ACTUAL=$(cat token.out)
[ "$ACTUAL" = "TOKEN=$TOKEN" ] || { echo 'Token verification failed' >&2; exit 1; }
printf '\nTask 2 PASSED: build #%s %s, artifact %s\n' "$BUILD_NUM" "$RESULT" "$ACTUAL"
