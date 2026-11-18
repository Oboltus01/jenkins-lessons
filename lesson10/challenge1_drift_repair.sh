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
def name = 'drift-target-job'
def job = j.getItemByFullName(name, FreeStyleProject)
if (job == null) {
  job = j.createProject(FreeStyleProject, name)
  println "[CREATE] ${name}"
} else {
  println "[UPDATE] ${name}"
}
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(new StringParameterDefinition('ENV_TIER', 'staging')))
job.getBuildersList().clear()
job.getBuildersList().add(new Shell('''#!/bin/sh
set -eu
rm -f tier.txt
printf 'tier=%s\n' "$ENV_TIER" > tier.txt
'''))
job.getPublishersList().clear()
def a = new ArtifactArchiver('tier.txt')
a.setOnlyIfSuccessful(true)
job.getPublishersList().add(a)
job.save()
println '[SUCCESS] Desired state restored'
GROOVY_CODE

echo '=== INITIAL PROVISION ==='
post_groovy
desired=$(cat "$GROOVY")
cat > "$GROOVY" <<'GROOVY_CODE'
import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.ArtifactArchiver

def job = Jenkins.get().getItemByFullName('drift-target-job', FreeStyleProject)
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(new StringParameterDefinition('ENV_TIER', 'broken-dev')))
job.getPublishersList().get(ArtifactArchiver.class).setOnlyIfSuccessful(false)
job.save()
println '[DRIFT] ENV_TIER=broken-dev, onlyIfSuccessful=false'
GROOVY_CODE
echo '=== SIMULATE DRIFT ==='
post_groovy
API="$BASE/job/drift-target-job"
config=$(curl -fsg "${auth[@]}" "$API/api/json?tree=property[parameterDefinitions[defaultParameterValue[value]]]")
if printf '%s' "$config" | grep -q '"value":"broken-dev"'; then
  echo '[DETECTED] Configuration drift'
  printf '%s\n' "$desired" > "$GROOVY"
  post_groovy
else
  echo 'Expected drift was not detected' >&2
  exit 1
fi
config=$(curl -fsg "${auth[@]}" "$API/api/json?tree=property[parameterDefinitions[defaultParameterValue[value]]]")
printf '%s' "$config" | grep -q '"value":"staging"' || { echo 'Parameter repair failed' >&2; exit 1; }
# Check archiver state independently through Jenkins Groovy.
cat > "$GROOVY" <<'GROOVY_CODE'
import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.tasks.ArtifactArchiver
def j = Jenkins.get().getItemByFullName('drift-target-job', FreeStyleProject)
println "ARCHIVER_OK=" + j.getPublishersList().get(ArtifactArchiver.class).isOnlyIfSuccessful()
GROOVY_CODE
check=$(post_groovy)
printf '%s' "$check" | grep -q 'ARCHIVER_OK=true' || { echo 'Archiver repair failed' >&2; exit 1; }
headers=$(mktemp)
trap 'rm -f "$COOKIE" "$GROOVY" "$headers"' EXIT
curl -fsS "${auth[@]}" -b "$COOKIE" -H "Jenkins-Crumb: $CRUMB" -X POST -D "$headers" -o /dev/null "$API/buildWithParameters?delay=0sec"
QUEUE_URL=$(grep -i '^Location:' "$headers" | awk '{print $2}' | tr -d '\r\n')
[ -n "$QUEUE_URL" ] || { echo 'Queue URL missing' >&2; exit 1; }
BUILD_NUM=''
for i in $(seq 1 60); do
  response=$(curl -sg "${auth[@]}" "${QUEUE_URL%/}/api/json?tree=executable[number]" || true)
  BUILD_NUM=$(printf '%s' "$response" | sed -n 's/.*"number":\([0-9]*\).*/\1/p')
  [ -n "$BUILD_NUM" ] && break
  sleep 1
done
[ -n "$BUILD_NUM" ] || { echo 'Build number unresolved' >&2; exit 1; }
RESULT=''
for i in $(seq 1 90); do
  response=$(curl -fsg "${auth[@]}" "$API/$BUILD_NUM/api/json?tree=building,result")
  if printf '%s' "$response" | grep -q '"building":false'; then
    RESULT=$(printf '%s' "$response" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
    break
  fi
  sleep 1
done
[ "$RESULT" = SUCCESS ] || { echo "Build failed: $RESULT" >&2; exit 1; }
curl -fsS "${auth[@]}" -o tier.txt "$API/$BUILD_NUM/artifact/tier.txt"
[ "$(cat tier.txt)" = 'tier=staging' ] || { echo 'Artifact mismatch' >&2; exit 1; }
printf '\nChallenge 1 PASSED: drift detected and repaired, build #%s %s, artifact tier=staging\n' "$BUILD_NUM" "$RESULT"
