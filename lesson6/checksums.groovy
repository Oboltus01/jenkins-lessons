import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell
import hudson.tasks.ArtifactArchiver

def instance = Jenkins.get()
def jobName = 'lesson6-artifact-demo'
def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

// Raw multi-line shell script string
String checksumShellScript = '''#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "  HOURS 7-8: MD5 CHECKSUMS & ARTIFACT ARCHIVAL"
echo "=========================================================="

mkdir -p ./dist/packages

echo "--> Step 1: Building binary release artifact..."
echo "BUILD_BIN_v1.0_STABLE_DATA" > ./dist/packages/app-v1.bin

echo "--> Step 2: Generating MD5 checksum..."
md5sum ./dist/packages/app-v1.bin | awk '{print $1}' > ./dist/packages/app-v1.bin.md5

echo "--> Step 3: Verifying MD5 checksum integrity..."
EXPECTED_HASH=$(cat ./dist/packages/app-v1.bin.md5)
ACTUAL_HASH=$(md5sum ./dist/packages/app-v1.bin | awk '{print $1}')

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "[ERROR] MD5 verification mismatch!" >&2
    exit 1
fi

echo "[SUCCESS] MD5 verification passed (${ACTUAL_HASH})."
'''

// Clear old build steps and attach shell builder
job.getBuildersList().clear()
job.getBuildersList().add(new Shell(checksumShellScript))

// Attach artifact archiver publisher post-build step
def archiver = new ArtifactArchiver('dist/packages/**/*')
archiver.setFingerprint(true)

job.getPublishersList().clear()
job.getPublishersList().add(archiver)

job.save()

println "LESSON6_HOURS7_8_PROVISIONED"
