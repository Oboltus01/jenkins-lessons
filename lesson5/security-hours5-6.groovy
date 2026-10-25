import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson5-webhook-demo'
def job = instance.getItem(jobName)
if (job == null) throw new IllegalStateException("Job not found: ${jobName}")

def tokenParam = new StringParameterDefinition('AUTH_TOKEN', '', 'Shared authentication token')
def payloadParam = new StringParameterDefinition('PAYLOAD_JSON', '{}', 'Webhook JSON payload')
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(tokenParam, payloadParam))

def securedShellScript = '''#!/usr/bin/env bash
set -euo pipefail

cleanup() {
    echo "[CLEANUP] Purging execution memory and temporary files..."
}
trap cleanup EXIT

EXPECTED_TOKEN="secure-webhook-secret-99"

echo "=========================================================="
echo "  HOURS 5-6: SECURITY & TOKEN VALIDATION"
echo "=========================================================="
echo "--> Step 1: Validating Authentication Token..."

if [ "${AUTH_TOKEN:-}" != "$EXPECTED_TOKEN" ]; then
    echo "[SECURITY ERROR] Invalid or missing auth token! Access denied." >&2
    exit 1
fi

echo "[SUCCESS] Token verified. Access granted."

EVENT_TYPE=$(printf '%s' "${PAYLOAD_JSON:-}" |
    grep -oE '"event"[[:space:]]*:[[:space:]]*"[^"]*"' |
    cut -d '"' -f4 || true)

EVENT_TYPE=${EVENT_TYPE:-unknown}
echo "--> Step 2: Executing task for event type: ${EVENT_TYPE}"
'''
job.getBuildersList().clear()
job.getBuildersList().add(new Shell(securedShellScript))
job.save()
println 'LESSON5_HOURS5_6_PROVISIONED'
