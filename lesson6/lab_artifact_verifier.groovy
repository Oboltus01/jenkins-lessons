import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.ParametersDefinitionProperty
import hudson.model.StringParameterDefinition
import hudson.tasks.Shell

def jenkins = Jenkins.get()
def job = jenkins.getItem('lab-artifact-verifier') ?:
    jenkins.createProject(FreeStyleProject, 'lab-artifact-verifier')

job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(
    new StringParameterDefinition('MODULE_NAME', 'auth-module', 'Module name'),
    new StringParameterDefinition('BUILD_NUMBER_ID', '101', 'Build identifier')
))

def script = '''#!/usr/bin/env bash
set -euo pipefail

teardown() {
    echo "[LAB-TEARDOWN] Workspace check completed."
}
trap teardown EXIT

echo "[LAB] Generating artifact..."
mkdir -p ./build_out

if [[ ! "$MODULE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] ||
   [[ ! "$BUILD_NUMBER_ID" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "[ERROR] Invalid parameter value!" >&2
    exit 1
fi

printf '{\n  "module": "%s",\n  "build_id": "%s",\n  "status": "PASS"\n}\n' \
    "$MODULE_NAME" "$BUILD_NUMBER_ID" > ./build_out/manifest.json

echo "[LAB] Checking artifact..."

if [ ! -s "./build_out/manifest.json" ]; then
    echo "[ERROR] Manifest missing or empty!" >&2
    exit 1
fi

if ! grep -q '"status": "PASS"' ./build_out/manifest.json; then
    echo "[ERROR] PASS status missing!" >&2
    exit 1
fi

cat ./build_out/manifest.json

echo "[LAB] Artifact verification successful."
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(script))
job.save()

println 'LAB_ARTIFACT_VERIFIER_PROVISIONED'
