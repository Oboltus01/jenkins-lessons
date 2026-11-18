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
def name = 'lab-provision-check'
def job = j.getItemByFullName(name, FreeStyleProject)
if (job == null) {
  job = j.createProject(FreeStyleProject, name)
  println "[CREATE] ${name}"
} else {
  println "[UPDATE] ${name}"
}
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(
  new StringParameterDefinition('APP_VERSION', '1.0.0', 'Application version'),
  new BooleanParameterDefinition('DRY_RUN', false, 'Dry run mode')
))
job.getBuildersList().clear()
job.getBuildersList().add(new Shell('''#!/bin/sh
set -eu
rm -f manifest.txt
printf 'version=%s\n' "$APP_VERSION" > manifest.txt
printf 'dry_run=%s\n' "$DRY_RUN" >> manifest.txt
'''))
job.getPublishersList().clear()
def a = new ArtifactArchiver('manifest.txt')
a.setOnlyIfSuccessful(true)
job.getPublishersList().add(a)
job.save()
println '[SUCCESS] Job configured: lab-provision-check'
GROOVY_CODE

echo '=== Provisioning Jenkins Job ==='
post_groovy
echo '=== Job Configuration ==='
curl -fsg "${auth[@]}" "$BASE/job/lab-provision-check/api/json?tree=name,property[parameterDefinitions[name,defaultParameterValue[value]]]"
echo
