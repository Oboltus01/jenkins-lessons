import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.Shell

def jenkins = Jenkins.get()
def jobName = 'lab-webhook-receiver'
def job = jenkins.getItem(jobName) ?:
    jenkins.createProject(FreeStyleProject, jobName)

def secretParam = new StringParameterDefinition('SECRET_KEY', '', 'Lab authentication key')
def payloadParam = new StringParameterDefinition('EVENT_PAYLOAD', '{}', 'Incoming JSON event')
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(secretParam, payloadParam))

def shellScript = '''#!/usr/bin/env bash
set -euo pipefail

cleanup() {
    echo "[LAB] Teardown complete."
}
trap cleanup EXIT

EXPECTED_SECRET="lab-secret-123"
if [ "${SECRET_KEY:-}" != "$EXPECTED_SECRET" ]; then
    echo "[ERROR] Invalid secret!" >&2
    exit 1
fi

ACTION=$(printf '%s' "${EVENT_PAYLOAD:-}" |
    grep -oE '"action"[[:space:]]*:[[:space:]]*"[^"]*"' |
    cut -d '"' -f4 || true)

COMPONENT=$(printf '%s' "${EVENT_PAYLOAD:-}" |
    grep -oE '"component"[[:space:]]*:[[:space:]]*"[^"]*"' |
    cut -d '"' -f4 || true)

ACTION=${ACTION:-unknown}
COMPONENT=${COMPONENT:-unknown}
echo "Processing action '${ACTION}' for component '${COMPONENT}'"
'''
job.getBuildersList().clear()
job.getBuildersList().add(new Shell(shellScript))
job.save()
println 'LAB_WEBHOOK_RECEIVER_PROVISIONED'
