import jenkins.model.Jenkins
import hudson.model.FreeStyleProject
import hudson.model.ParametersDefinitionProperty
import hudson.model.StringParameterDefinition
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson7-audit-aggregator'
def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(
    new StringParameterDefinition('WORKER_COUNT', '4', 'Number of parallel audit workers (1-16)'),
    new StringParameterDefinition('SIMULATE_LATENCY', 'true', 'true to sleep for 1-3 seconds per worker')
))

String auditShell = '''#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " LESSON 7: MULTITHREADED LOG AGGREGATOR & AUDIT"
echo "=================================================="

[[ "${WORKER_COUNT}" =~ ^([1-9]|1[0-6])$ ]] || { echo "[ERROR] WORKER_COUNT must be an integer from 1 to 16" >&2; exit 2; }
[[ "${SIMULATE_LATENCY}" == "true" || "${SIMULATE_LATENCY}" == "false" ]] || {
    echo "[ERROR] SIMULATE_LATENCY must be true or false" >&2
    exit 2
}

mkdir -p ./logs ./build_out
rm -f ./logs/worker_*.log ./logs/worker_*.json \
      ./build_out/audit_summary.json ./build_out/audit_summary.json.md5

PIDS=()
cleanup() {
    local exit_code=$?
    trap - EXIT
    echo "[CLEANUP] Exit code: $exit_code"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "[CLEANUP] Terminating worker PID $pid"
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

audit_worker() {
    local id="$1"
    local pid="$BASHPID"
    echo "[WORKER $id] Started, PID $pid"
    if [[ "$SIMULATE_LATENCY" == "true" ]]; then
        local delay=$((RANDOM % 3 + 1))
        echo "[WORKER $id] Simulated latency: ${delay}s"
        sleep "$delay"
    fi
    printf '{"worker_id":"%s","pid":"%s","status":"COMPLETED"}\\n' \
        "$id" "$pid" > "./logs/worker_${id}.json"
    echo "[WORKER $id] COMPLETED"
}

echo "[SPAWN] Launching $WORKER_COUNT parallel workers..."
for ((id=1; id<=WORKER_COUNT; id++)); do
    audit_worker "$id" > "./logs/worker_${id}.log" 2>&1 &
    PIDS+=("$!")
    echo "[SPAWNED] Worker $id, PID $!"
done

FAILED=0
for idx in "${!PIDS[@]}"; do
    pid="${PIDS[$idx]}"
    if wait "$pid"; then
        echo "[SYNC SUCCESS] Worker $((idx+1)), PID $pid"
    else
        echo "[SYNC FAILURE] Worker $((idx+1)), PID $pid" >&2
        FAILED=1
    fi
done

echo "=== WORKER LOGS ==="
for ((id=1; id<=WORKER_COUNT; id++)); do
    echo "--- logs/worker_${id}.log ---"
    cat "./logs/worker_${id}.log"
done

if [[ "$FAILED" -ne 0 ]]; then
    echo "[ERROR] At least one worker failed; audit manifest not marked successful." >&2
    exit 1
fi

summary="./build_out/audit_summary.json"
{
    printf '{\\n  "worker_count": %s,\\n  "status": "COMPLETED",\\n  "workers": [\\n' "$WORKER_COUNT"
    for ((id=1; id<=WORKER_COUNT; id++)); do
        file="./logs/worker_${id}.json"
        [[ -s "$file" ]] || { echo "[ERROR] Missing status JSON: $file" >&2; exit 1; }
        if (( id > 1 )); then printf ',\\n'; fi
        printf '    '
        tr -d '\\n' < "$file"
    done
    printf '\\n  ]\\n}\\n'
} > "$summary"

(
    cd ./build_out
    md5sum audit_summary.json > audit_summary.json.md5
    md5sum -c audit_summary.json.md5
)

echo "=== AUDIT SUMMARY ==="
cat "$summary"
echo "=== MD5 DIGEST ==="
cat ./build_out/audit_summary.json.md5
echo "[AUDIT SUCCESS] All workers completed; audit manifest verified."
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(auditShell))
job.save()
println 'LESSON7_AUDIT_AGGREGATOR_PROVISIONED'
