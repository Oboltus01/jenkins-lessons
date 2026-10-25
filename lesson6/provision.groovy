import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson6-artifact-demo'

def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

// Register string parameter for target build environment
def envParam = new StringParameterDefinition('BUILD_ENV', 'STAGING', 'Target Environment')
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(envParam))

def shellScript = '''#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "  HOURS 1-2: WORKSPACE ARTIFACT GENERATION"
echo "=========================================================="

echo "--> Step 1: Creating build workspace directories..."
mkdir -p ./output/reports

echo "--> Step 2: Generating build manifest artifact..."
cat << MANIFEST > ./output/build_manifest.json
{
  "job_name": "${JOB_NAME}",
  "build_number": "${BUILD_NUMBER}",
  "environment": "${BUILD_ENV}",
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "status": "SUCCESS"
}
MANIFEST

echo "--> Step 3: Generating execution log report..."
echo "[INFO] Build started for environment ${BUILD_ENV}" > ./output/reports/execution.log
echo "[INFO] Artifacts generated successfully at $(date)" >> ./output/reports/execution.log

echo -e "\n--> Step 4: Listing generated workspace files:"
ls -la ./output/
ls -la ./output/reports/
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(shellScript))
job.save()

println "LESSON6_HOURS1_2_PROVISIONED"
