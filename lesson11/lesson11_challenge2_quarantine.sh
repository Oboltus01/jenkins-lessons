#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8080"
NODE="pool-node-1"
JOB="pool-health-worker"
ADDED_LABEL=0

groovy() {
    curl -fsS -X POST "$BASE/scriptText" \
        --data-urlencode "script=$1"
}

cleanup() {
    echo "[CLEANUP] Restoring fleet"

    groovy "
import jenkins.model.Jenkins

def j = Jenkins.get()
def n = j.getNode('pool-node-1')

if (n != null) {
    def c = n.toComputer()

    if (c?.isTemporarilyOffline()) {
        c.setTemporarilyOffline(false, null)
        println 'UNCORDONED: pool-node-1'
    }

    if (c?.isIdle()) {
        j.removeNode(n)
        println 'REMOVED_AGENT: pool-node-1'
    }
}

if (${ADDED_LABEL} == 1) {
    def labels = j.getLabelString().tokenize()
        .findAll { it != 'worker-pool' }
        .join(' ')
    j.setLabelString(labels)
    j.save()
    println 'CONTROLLER_LABEL_RESTORED'
}
" || true
}

trap cleanup EXIT

echo "=== LESSON 11: CHALLENGE 2 ==="

echo
echo "[1] BOOTSTRAP FLEET AND JOB"

SETUP=$(cat <<'GROOVY'
import jenkins.model.Jenkins
import hudson.model.*
import hudson.slaves.*
import hudson.tasks.*

def j = Jenkins.get()

def n = j.getNode("pool-node-1")

if (n == null) {
    n = new DumbSlave(
        "pool-node-1",
        "/tmp/pool-node-1",
        new JNLPLauncher(true)
    )
    n.setNumExecutors(1)
    n.setMode(Node.Mode.NORMAL)
    n.setLabelString("worker-pool")
    j.addNode(n)
    println "CREATED_AGENT: pool-node-1"
}

def labels = j.getLabelString().tokenize()

if (!labels.contains("worker-pool")) {
    j.setLabelString(
        (labels + ["worker-pool"]).join(" ")
    )
    j.save()
    println "ADDED_CONTROLLER_LABEL"
}

def job = j.getItem("pool-health-worker")

if (job == null) {
    job = j.createProject(
        FreeStyleProject,
        "pool-health-worker"
    )
}

job.setAssignedLabel(j.getLabel("worker-pool"))
job.getBuildersList().clear()

job.getBuildersList().add(
    new Shell('''echo "EXECUTED_NODE=${NODE_NAME}" > placement.txt''')
)

job.getPublishersList().clear()

def archiver = new ArtifactArchiver("placement.txt")
archiver.setOnlyIfSuccessful(true)
job.getPublishersList().add(archiver)

job.save()

println "JOB_READY: pool-health-worker"
GROOVY
)

SETUP_RESULT=$(groovy "$SETUP")
echo "$SETUP_RESULT"

grep -q "JOB_READY:" <<< "$SETUP_RESULT"

if grep -q "ADDED_CONTROLLER_LABEL" <<< "$SETUP_RESULT"; then
    ADDED_LABEL=1
fi

echo
echo "[2] QUARANTINE DEGRADED NODE"

STATE=$(curl -fsS -g \
  "$BASE/computer/$NODE/api/json?tree=temporarilyOffline" |
  python3 -c '
import json,sys
print(str(json.load(sys.stdin)["temporarilyOffline"]).lower())
')

if [ "$STATE" = "false" ]; then
    curl -fsS -X POST \
      --data-urlencode \
      "offlineMessage=Degraded Node Quarantined" \
      "$BASE/computer/$NODE/toggleOffline"

    echo "CORDONED: $NODE"
else
    echo "ALREADY CORDONED: $NODE"
fi

curl -fsS -g \
  "$BASE/computer/$NODE/api/json?tree=temporarilyOffline,offlineCauseReason" |
  python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["temporarilyOffline"] is True
assert "Degraded Node Quarantined" in d["offlineCauseReason"]
print("QUARANTINE VERIFIED")
'

echo
echo "[3] TRIGGER JOB"

HEADERS=$(curl -fsS -D - -o /dev/null \
  -X POST "$BASE/job/$JOB/build?delay=0sec")

QUEUE_URL=$(printf '%s\n' "$HEADERS" |
  awk 'tolower($1)=="location:" {
    gsub("\r","",$2); print $2
  }')

echo "QUEUE_URL: $QUEUE_URL"

QUEUE_ID=$(echo "$QUEUE_URL" |
  sed -n 's#.*/queue/item/\([0-9]*\)/#\1#p')

test -n "$QUEUE_ID" || exit 1

echo "QUEUE_ID: $QUEUE_ID"

echo
echo "[4] WAIT FOR EXACT BUILD"

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

    [ -n "$BUILD_NUMBER" ] && break
    sleep 2
done

test -n "$BUILD_NUMBER" || {
    echo "[FAIL] Build not found"
    exit 1
}

echo "BUILD_NUMBER: $BUILD_NUMBER"

echo
echo "[5] VERIFY BUILD SUCCESS"

STATUS=""

for i in $(seq 1 60); do
    STATUS=$(curl -fsS \
      "$BASE/job/$JOB/$BUILD_NUMBER/api/json" |
      python3 -c '
import json,sys
d=json.load(sys.stdin)
print("BUILDING" if d["building"]
      else d.get("result","UNKNOWN"))
')

    echo "BUILD STATUS: $STATUS"

    [ "$STATUS" = "SUCCESS" ] && break

    if [ "$STATUS" != "BUILDING" ]; then
        echo "[FAIL] Build result: $STATUS"
        exit 1
    fi

    sleep 2
done

[ "$STATUS" = "SUCCESS" ] || exit 1

echo
echo "[6] VERIFY PLACEMENT"

curl -fsS \
  "$BASE/job/$JOB/$BUILD_NUMBER/artifact/placement.txt" \
  -o placement.txt

cat placement.txt

grep -Fxq "EXECUTED_NODE=built-in" placement.txt

echo "PLACEMENT VERIFIED: built-in"

echo
echo "[SUCCESS] CHALLENGE 2 PASSED"
