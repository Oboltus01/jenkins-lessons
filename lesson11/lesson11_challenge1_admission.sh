#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8080"
JOB="payment-batch-worker"

groovy() {
    curl -fsS -X POST "$BASE/scriptText" \
        --data-urlencode "script=$1"
}

echo "=== LESSON 11: CHALLENGE 1 ==="
echo "Admission Controller & Backpressure"

echo
echo "[1] BOOTSTRAP JOB AND CAPACITY"

ORIGINAL_EXECS=$(groovy '
import jenkins.model.Jenkins
println Jenkins.get().getNumExecutors()
' | tr -d '\r\n')

[[ "$ORIGINAL_EXECS" =~ ^[0-9]+$ ]] || exit 1

restore() {
    echo "[CLEANUP] Restoring executors: $ORIGINAL_EXECS"
    groovy "
import jenkins.model.Jenkins
def j = Jenkins.get()
j.setNumExecutors($ORIGINAL_EXECS)
j.save()
println 'CAPACITY_RESTORED'
" || true
}

trap restore EXIT

groovy '
import jenkins.model.Jenkins
import hudson.model.*
import hudson.tasks.*

def j = Jenkins.get()

j.setNumExecutors(1)
j.save()

def job = j.getItem("payment-batch-worker")

if (job == null) {
    job = j.createProject(
        FreeStyleProject,
        "payment-batch-worker"
    )
}

job.setAssignedLabel(j.getLabel("built-in"))

job.removeProperty(ParametersDefinitionProperty)

job.addProperty(new ParametersDefinitionProperty(
    new StringParameterDefinition(
        "BATCH_ID", "", "Batch identifier"
    )
))

job.getBuildersList().clear()
job.getBuildersList().add(
    new Shell('\''sleep 4\n echo "BATCH_ID=${BATCH_ID}" > batch.receipt'\'')
)

job.getPublishersList().clear()
def archiver = new ArtifactArchiver("batch.receipt")
archiver.setOnlyIfSuccessful(true)
job.getPublishersList().add(archiver)

job.save()

println "JOB_READY: payment-batch-worker"
println "EXECUTORS: 1"
'

START_NUMBER=$(curl -fsS \
    "$BASE/job/$JOB/api/json?tree=nextBuildNumber" |
    python3 -c '
import json,sys
print(json.load(sys.stdin)["nextBuildNumber"])
')

dispatch() {
    local batch="$1"
    local code

    code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        --data-urlencode "BATCH_ID=$batch" \
        "$BASE/job/$JOB/buildWithParameters?delay=0sec")

    echo "DISPATCH $batch: HTTP $code"

    [[ "$code" == "201" ]]
}

echo
echo "[2] SIMULATE TRAFFIC BURST"

dispatch "BATCH-1"

# Confirm the first build occupies the executor.
RUNNING=0
for i in $(seq 1 40); do
    RUNNING=$(curl -fsS -g \
        "$BASE/job/$JOB/api/json?tree=builds[number,building]" |
        python3 -c '
import json,sys
d=json.load(sys.stdin)
start=int(sys.argv[1])
print(int(any(
    b["number"] >= start and b["building"]
    for b in d.get("builds",[])
)))
' "$START_NUMBER")

    [ "$RUNNING" = "1" ] && break
    sleep 0.1
done

[ "$RUNNING" = "1" ] || {
    echo "[FAIL] First build did not start"
    exit 1
}

dispatch "BATCH-2"
dispatch "BATCH-3"

echo
echo "[3] ADMISSION GATE FOR BATCH-4"

QUEUE_COUNT=$(curl -fsS -g \
    "$BASE/queue/api/json?tree=items[id,task[name]]" |
    python3 -c '
import json,sys
print(len(json.load(sys.stdin)["items"]))
')

echo "QUEUE_COUNT: $QUEUE_COUNT"

if [ "$QUEUE_COUNT" -ge 2 ]; then
    echo "[ADMISSION DENIED] Queue saturation threshold reached ($QUEUE_COUNT items waiting)"
    echo "BATCH-4 NOT DISPATCHED"
else
    echo "[FAIL] Queue threshold not reached"
    exit 1
fi

echo
echo "[4] DRAIN AND VERIFY"

COMPLETE=0

for i in $(seq 1 60); do
    RESULT=$(curl -fsS -g \
        "$BASE/job/$JOB/api/json?tree=builds[number,result,building]" |
        python3 -c '
import json,sys
d=json.load(sys.stdin)
start=int(sys.argv[1])
builds=[
    b for b in d.get("builds",[])
    if b["number"] >= start
]
success=sum(
    b.get("result")=="SUCCESS"
    for b in builds
)
print(len(builds),success)
' "$START_NUMBER")

    read -r TOTAL SUCCESS <<< "$RESULT"
    echo "BUILDS: $TOTAL | SUCCESS: $SUCCESS"

    if [ "$TOTAL" -eq 3 ] && [ "$SUCCESS" -eq 3 ]; then
        COMPLETE=1
        break
    fi

    sleep 1
done

[ "$COMPLETE" = "1" ] || {
    echo "[FAIL] Expected three successful builds"
    exit 1
}

echo
echo "[5] VERIFY ARCHIVED RECEIPTS"

for offset in 0 1 2; do
    number=$((START_NUMBER + offset))
    expected="BATCH-$((offset + 1))"

    receipt=$(curl -fsS \
        "$BASE/job/$JOB/$number/artifact/batch.receipt")

    echo "Build #$number: $receipt"
    [ "$receipt" = "BATCH_ID=$expected" ]
done

echo
echo "[SUCCESS] CHALLENGE 1 PASSED"
echo "Three builds completed, fourth rejected."
