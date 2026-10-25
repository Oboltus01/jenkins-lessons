import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson6-artifact-demo'
def job = instance.getItem(jobName)

def validationShellScript = '''#!/usr/bin/env bash
set -euo pipefail

# 1. Setup Cleanup Trap
teardown() {
    echo -e "\n[CLEANUP] Post-execution state check finished."
}
trap teardown EXIT

echo "=========================================================="
echo "  HOURS 3-4: ARTIFACT INTEGRITY & FAILURE GATES"
echo "=========================================================="

MANIFEST_PATH="./output/build_manifest.json"

echo "--> Step 1: Generating Build Manifest..."
mkdir -p ./output
cat << 'MANIFEST' > ./output/build_manifest.json
{
  "job_name": "lesson6-artifact-demo",
  "status": "COMPLETED",
  "checksum_verified": true
}
MANIFEST

echo "--> Step 2: Validating file existence and size..."
if [ ! -f "${MANIFEST_PATH}" ]; then
    echo "[ERROR] Manifest file '${MANIFEST_PATH}' was not created!" >&2
    exit 1
fi

if [ ! -s "${MANIFEST_PATH}" ]; then
    echo "[ERROR] Manifest file '${MANIFEST_PATH}' is empty (0 bytes)!" >&2
    exit 1
fi

echo "[CHECK PASSED] File exists and is non-empty."

echo "--> Step 3: Validating content integrity..."
if ! grep -q '"status": "COMPLETED"' "${MANIFEST_PATH}"; then
    echo "[ERROR] Manifest status validation failed!" >&2
    exit 1
fi

echo "[CHECK PASSED] Manifest status string verified."
echo "[SUCCESS] All workspace artifacts passed integrity gates."
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(validationShellScript))
job.save()

println "LESSON6_HOURS3_4_PROVISIONED"
