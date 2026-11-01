import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson7-parallel-demo'

def job = instance.getItem(jobName) ?: instance.createProject(FreeStyleProject, jobName)

// Register parallel execution thread count parameter
def threadsParam = new StringParameterDefinition('PARALLEL_THREADS', '3', 'Number of parallel worker subshells')
job.removeProperty(ParametersDefinitionProperty.class)
job.addProperty(new ParametersDefinitionProperty(threadsParam))

String parallelShellScript = '''#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo "  HOURS 1-2: ASYNCHRONOUS SUBSHELL PARALLELISM"
echo "=========================================================="

# Directory for subshell thread logs
mkdir -p ./logs/threads

# Arrays to capture Process IDs (PIDs) and worker indices
PIDS=()
WORKERS=(${PARALLEL_THREADS})

echo "--> Step 1: Spawning ${PARALLEL_THREADS} parallel subshell tasks..."

worker_task() {
    local worker_id=$1
    local log_file="./logs/threads/worker_${worker_id}.log"
    
    echo "[WORKER ${worker_id}] Task started at $(date +%H:%M:%S)" > "${log_file}"
    
    # Simulate non-blocking asynchronous work with varying execution times
    local sleep_time=$(( (RANDOM % 3) + 1 ))
    sleep "${sleep_time}"
    
    echo "[WORKER ${worker_id}] Completed work in ${sleep_time}s" >> "${log_file}"
}

# Loop to spawn background subshells
for i in $(seq 1 "${PARALLEL_THREADS}"); do
    worker_task "${i}" &
    PID=$!
    PIDS+=("${PID}")
    echo "  [SPAWNED] Worker Thread ${i} assigned PID ${PID}"
done

echo -e "\n--> Step 2: Synchronizing subshell completion (Waiting on PIDs: ${PIDS[*]})..."

# Track failure states across threads
FAILED=0

for idx in "${!PIDS[@]}"; do
    PID="${PIDS[$idx]}"
    WORKER_NUM=$((idx + 1))
    
    if wait "${PID}"; then
        echo "  [SYNC SUCCESS] Worker ${WORKER_NUM} (PID ${PID}) finished cleanly."
    else
        echo "  [SYNC FAILURE] Worker ${WORKER_NUM} (PID ${PID}) exited with non-zero status!" >&2
        FAILED=1
    fi
done

if [ "${FAILED}" -ne 0 ]; then
    echo "[ERROR] One or more parallel subshells failed execution!" >&2
    exit 1
fi

echo -e "\n--> Step 3: Inspecting aggregated parallel thread logs:"
for log in ./logs/threads/*.log; do
    echo "--- File: ${log} ---"
    cat "${log}"
done

echo "[SUCCESS] All parallel tasks synchronized successfully."
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(parallelShellScript))
job.save()

println "LESSON7_HOURS1_2_PROVISIONED"
