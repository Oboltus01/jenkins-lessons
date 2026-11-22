#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8080"
NODE="pt2-offline-agent"
JOB="pt2-failover-job"

groovy() {
    curl -fsS -X POST "$BASE/scriptText" \
        --data-urlencode "script=$1"
}

echo "=== PT2: QUEUE FAILOVER ==="

echo
echo "[1] CREATE OFFLINE AGENT AND JOB"

groovy '
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher
import hudson.model.Node
import hudson.model.FreeStyleProject
import hudson.tasks.Shell
import hudson.tasks.ArtifactArchiver

def j = Jenkins.get()

def node = j.getNode("pt2-offline-agent")

if (node == null) {
    node = new DumbSlave(
        "pt2-offline-agent",
        "/tmp/pt2-agent",
        new JNLPLauncher(true)
    )
    node.setNumExecutors(1)
    node.setMode(Node.Mode.EXCLUSIVE)
    node.setLabelString("isolated-zone")
    j.addNode(node)
    println "CREATED_AGENT: pt2-offline-agent"
}

def job = j.getItem("pt2-failover-job")

if (job == null) {
    job = j.createProject(
        FreeStyleProject,
        "pt2-failover-job"
    )
}

job.setAssignedLabel(j.getLabel("isolated-zone"))

job.getBuildersList().clear()
job.getBuildersList().add(
    new Shell('\''echo "RAN_ON=${NODE_NAME}" > where.txt'\'')
)

job.getPublishersList().clear()

def archiver = new ArtifactArchiver("where.txt")
archiver.setOnlyIfSuccessful(true)
job.getPublishersList().add(archiver)

job.save()

println "JOB_BOUND_TO: isolated-zone"
'

echo
echo "[2] VERIFY OFFLINE AGENT"

curl -fsS -g \
  "$BASE/computer/$NODE/api/json?tree=offline" \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["offline"] is True
print("AGENT OFFLINE VERIFIED")
'

echo
echo "[3] DISPATCH JOB"

HEADERS=$(curl -fsS -D - -o /dev/null -X POST \
    "$BASE/job/$JOB/build?delay=0sec")

QUEUE_URL=$(printf '%s\n' "$HEADERS" |
    awk 'tolower($1)=="location:" {gsub("\r","",$2); print $2}')

test -n "$QUEUE_URL" || {
    echo "[FAIL] Queue URL missing"
    exit 1
}

echo "QUEUE_URL: $QUEUE_URL"

sleep 2

echo
echo "[4] VERIFY STALLED QUEUE"

curl -fsS -g \
  "${QUEUE_URL}api/json?tree=id,why" \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)
reason=d.get("why") or ""
print("QUEUE ID:",d["id"])
print("WAIT REASON:",reason)
assert reason, "Expected queued workload"
'

QUEUE_ID=$(echo "$QUEUE_URL" |
    sed -n 's#.*/queue/item/\([0-9]*\)/#\1#p')

test -n "$QUEUE_ID"

echo
echo "[5] FAILOVER TO BUILT-IN NODE"

groovy '
import jenkins.model.Jenkins

def j = Jenkins.get()
def job = j.getItem("pt2-failover-job")

job.setAssignedLabel(j.getLabel("built-in"))
job.save()

println "REBOUND_TO: built-in"
'

echo
echo "[6] WAIT FOR BUILD"

BUILD_NUMBER=""

for i in $(seq 1 60); do
    BUILD_NUMBER=$(curl -fsS -g \
      "$BASE/job/$JOB/api/json?tree=builds[number,queueId]" |
      python3 -c '
import json,sys
d=json.load(sys.stdin)
target=int(sys.argv[1])
for b in d.get("builds",[]):
    if b.get("queueId")==target:
        print(b["number"])
        break
' "$QUEUE_ID")

    if [ -n "$BUILD_NUMBER" ]; then
        break
    fi

    sleep 2
done

test -n "$BUILD_NUMBER" || {
    echo "[FAIL] Build not scheduled"
    exit 1
}

echo "BUILD_NUMBER: $BUILD_NUMBER"

for i in $(seq 1 60); do
    BUILD_JSON=$(curl -fsS \
      "$BASE/job/$JOB/$BUILD_NUMBER/api/json")

    STATUS=$(echo "$BUILD_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
if d["building"]:
    print("BUILDING")
else:
    print(d.get("result") or "UNKNOWN")
')

    echo "BUILD STATUS: $STATUS"

    if [ "$STATUS" = "SUCCESS" ]; then
        break
    fi

    if [ "$STATUS" != "BUILDING" ]; then
        echo "[FAIL] Build finished: $STATUS"
        exit 1
    fi

    sleep 2
done

test "$STATUS" = "SUCCESS"

echo
echo "[7] VERIFY ARTIFACT"

curl -fsS \
  "$BASE/job/$JOB/$BUILD_NUMBER/artifact/where.txt" \
  -o where.txt

cat where.txt

grep -Fxq "RAN_ON=built-in" where.txt

echo
echo "[8] CLEAN UP OFFLINE AGENT"

groovy '
import jenkins.model.Jenkins

def j=Jenkins.get()
def node=j.getNode("pt2-offline-agent")

if(node != null && node.toComputer()?.isIdle()) {
    j.removeNode(node)
    println "REMOVED_AGENT: pt2-offline-agent"
}
'

echo
echo "[SUCCESS] PRACTICE TEST 2 PASSED"
