import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.ParametersDefinitionProperty
import hudson.model.StringParameterDefinition
import hudson.tasks.Shell

def jenkins = Jenkins.get()
def jobName = 'lesson7-capstone-pipeline'
def job = jenkins.getItem(jobName) ?: jenkins.createProject(FreeStyleProject, jobName)

job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(
    new StringParameterDefinition('SERVICE_COUNT', '3', 'Parallel worker count (1-8)'),
    new StringParameterDefinition('SIMULATE_FAILURE', 'false', 'true: worker 2 fails all retries')
))

String shellScript = '''#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " LESSON 7 CAPSTONE: SELF-HEALING PARALLEL ENGINE"
echo "=================================================="

[[ "${SERVICE_COUNT}" =~ ^[1-8]$ ]] || { echo "[ERROR] SERVICE_COUNT must be 1-8" >&2; exit 2; }
[[ "${SIMULATE_FAILURE}" == "true" || "${SIMULATE_FAILURE}" == "false" ]] || {
    echo "[ERROR] SIMULATE_FAILURE must be true or false" >&2; exit 2;
}

mkdir -p ./logs ./build_out
rm -f ./logs/worker_*.log ./build_out/status.json ./build_out/emergency.json

PIDS=()
WATCHDOG_PID=""

cleanup() {
    trap - EXIT
    echo "[CLEANUP] Checking background processes..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    if [[ -n "$WATCHDOG_PID" ]] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        kill -TERM "$WATCHDOG_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

worker() {
    local id="$1"
    local attempt
    for attempt in 1 2 3; do
        echo "[WORKER $id] Attempt $attempt/3"
        if [[ "$SIMULATE_FAILURE" == "true" && "$id" -eq 2 ]]; then
            echo "[WORKER $id] Simulated transient failure"
        elif [[ "$attempt" -lt 2 ]]; then
            echo "[WORKER $id] Transient error: will retry"
        else
            echo "[WORKER $id] Synchronization succeeded"
            return 0
        fi
        if [[ "$attempt" -lt 3 ]]; then
            sleep 1
        fi
    done
    echo "[WORKER $id] Retry limit exhausted" >&2
    return 1
}

echo "[START] Spawning ${SERVICE_COUNT} workers..."
for ((id=1; id<=SERVICE_COUNT; id++)); do
    worker "$id" >"./logs/worker_${id}.log" 2>&1 &
    PIDS+=("$!")
    echo "[SPAWNED] Worker $id PID ${PIDS[-1]}"
done

# Watchdog runs concurrently with the worker processes.
watchdog() {
    sleep 5
    local pid
    for pid in "$@"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "[TIMEOUT] Worker PID $pid exceeded the 5-second limit" >&2
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
}
watchdog "${PIDS[@]}" &
WATCHDOG_PID=$!
echo "[WATCHDOG] PID $WATCHDOG_PID, timeout 5s"

FAILED=0
for idx in "${!PIDS[@]}"; do
    pid="${PIDS[$idx]}"
    if wait "$pid"; then
        echo "[SYNC SUCCESS] Worker $((idx + 1))"
    else
        echo "[SYNC FAILURE] Worker $((idx + 1)), PID $pid" >&2
        FAILED=1
    fi
done

kill -TERM "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true
WATCHDOG_PID=""

echo "=== AGGREGATED WORKER LOGS ==="
for log in ./logs/worker_*.log; do
    echo "--- $log ---"
    cat "$log"
done

if [[ "$FAILED" -ne 0 ]]; then
    printf '{"status":"FALLBACK_TRIGGERED","recovery":"EMERGENCY","service_count":%s,"build_result":"FAILURE"}\n' \
        "$SERVICE_COUNT" > ./build_out/emergency.json
    echo "[FALLBACK] Emergency manifest generated:"
    cat ./build_out/emergency.json
    exit 1
fi

printf '{"status":"SUCCESS","service_count":%s,"build_result":"SUCCESS"}\n' \
    "$SERVICE_COUNT" > ./build_out/status.json
echo "[SUCCESS] All workers synchronized:"
cat ./build_out/status.json
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(shellScript))
job.save()
println 'LESSON7_CAPSTONE_PROVISIONED'
