import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson6-capstone-pipeline'

def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

def paramApp = new StringParameterDefinition('APP_NAME', 'billing-service', 'Application Name')
def paramVer = new StringParameterDefinition('RELEASE_VERSION', 'v3.1.0', 'Release Version')

job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(paramApp, paramVer))

def capstoneShell = '''#!/usr/bin/env bash
set -euo pipefail

teardown() {
    echo -e "\n[TEARDOWN] Workspace inspection completed."
}
trap teardown EXIT

echo "=========================================================="
echo "  HOURS 9-10: CAPSTONE ARTIFACT INSPECTION PIPELINE"
echo "=========================================================="

echo "--> Step 1: Creating distribution artifacts..."
mkdir -p ./dist

cat << MANIFEST > ./dist/release.json
{
  "app": "${APP_NAME}",
  "version": "${RELEASE_VERSION}",
  "verified": true
}
MANIFEST

echo "--> Step 2: Executing file validation gates..."
if [ ! -s "./dist/release.json" ]; then
    echo "[ERROR] Release manifest missing or empty!" >&2
    exit 1
fi

if ! grep -q '"verified": true' "./dist/release.json"; then
    echo "[ERROR] Manifest verification flag check failed!" >&2
    exit 1
fi

echo "[SUCCESS] Release manifest integrity verified."

echo -e "\n--> Step 3: Manifest Artifact Contents:"
cat ./dist/release.json
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(capstoneShell))
job.save()

println "LESSON6_CAPSTONE_PROVISIONED"
