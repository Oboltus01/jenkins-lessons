import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson5-webhook-demo'
def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

def payloadParam = new StringParameterDefinition(
    'PAYLOAD_JSON',
    '{"event":"default"}',
    'Raw JSON payload delivered by inbound webhook'
)
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(payloadParam))

def parsingShellScript = '''#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "  HOURS 3-4: JSON EXTRACTION AND PARSING"
echo "=========================================================="

# Lesson demo: compact string parsing of simple JSON. Use jq for real JSON.
EVENT_TYPE=$(echo "${PAYLOAD_JSON}" | grep -o '"event":"[^"]*"' | cut -d'"' -f4 || true)
REPOSITORY=$(echo "${PAYLOAD_JSON}" | grep -o '"repo":"[^"]*"' | cut -d'"' -f4 || true)
ACTION=$(echo "${PAYLOAD_JSON}" | grep -o '"action":"[^"]*"' | cut -d'"' -f4 || true)

EVENT_TYPE=${EVENT_TYPE:-unknown}
REPOSITORY=${REPOSITORY:-unknown}
ACTION=${ACTION:-none}

echo "Parsed Event      : ${EVENT_TYPE}"
echo "Parsed Repository : ${REPOSITORY}"
echo "Parsed Action     : ${ACTION}"

echo ""
echo "--> Evaluating Workflow Routing:"
if [ "${EVENT_TYPE}" = "release" ]; then
    echo "[ACTION] Production release detected. Initializing artifact deployment..."
elif [ "${EVENT_TYPE}" = "push" ]; then
    echo "[ACTION] Source code update detected. Running unit testing suite..."
else
    echo "[INFO] Event '${EVENT_TYPE}' requires no secondary tasks."
fi
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(parsingShellScript))
job.save()
println "LESSON5_HOURS3_4_PROVISIONED"
