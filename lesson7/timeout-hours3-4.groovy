import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell

def instance = Jenkins.get()
def jobName = 'lesson7-parallel-demo'
def job = instance.getItem(jobName)

String timeoutShellScript = '''#!/usr/bin/env bash
set -euo pipefail

# Maximum allowable execution window in seconds
TIMEOUT_LIMIT=3

echo "=========================================================="
echo "  HOURS 3-4: PROCESS ISOLATION & TIMEOUT GUARDS"
echo "=========================================================="

# Global PID cleanup registry
ACTIVE_PIDS=()

# Comprehensive termination handler to kill orphaned processes
cleanup_processes() {
    local exit_code=$?
    echo -e "\n[CLEANUP] Executing process isolation sweep (Exit Code: ${exit_code})..."
    for pid in "${ACTIVE_PIDS[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            echo "  [TERMINATING] Terminating lingering process PID ${pid}..."
            kill -9 "${pid}" 2>/dev/null || true
        fi
    done
}

# Bind cleanup handler to EXIT and SIGTERM signals
trap cleanup_processes EXIT SIGTERM

# Simulate long-running worker subshell
long_running_worker() {
    echo "[WORKER] Initialized hanging work thread (PID $$)..."
    # Intentionally exceeds the 3-second limit
    sleep 10
    echo "[WORKER] Task finished successfully."
}

# 1. Launch worker in background
long_running_worker &
WORKER_PID=$!
ACTIVE_PIDS+=("${WORKER_PID}")
echo "--> Worker spawned with PID: ${WORKER_PID}"

# 2. Launch watchdog process in background
watchdog() {
    local target_pid=$1
    local limit=$2
    sleep "${limit}"
    if kill -0 "${target_pid}" 2>/dev/null; then
        echo -e "\n[TIMEOUT EXCEEDED] Worker PID ${target_pid} passed ${limit}s threshold!" >&2
        echo "[TIMEOUT EXCEEDED] Dispatching SIGTERM to force worker termination..." >&2
        kill -15 "${target_pid}" 2>/dev/null || true
    fi
}

watchdog "${WORKER_PID}" "${TIMEOUT_LIMIT}" &
WATCHDOG_PID=$!
ACTIVE_PIDS+=("${WATCHDOG_PID}")
echo "--> Watchdog initialized with PID: ${WATCHDOG_PID} (Limit: ${TIMEOUT_LIMIT}s)"

# 3. Wait for worker process
echo "--> Main process entering synchronization block..."
if wait "${WORKER_PID}"; then
    echo "[SUCCESS] Worker completed before timeout threshold."
    # Kill watchdog since worker completed naturally
    kill -9 "${WATCHDOG_PID}" 2>/dev/null || true
else
    echo "[FAILURE] Worker execution interrupted or terminated by watchdog!" >&2
    exit 1
fi
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(timeoutShellScript))
job.save()

println "LESSON7_HOURS3_4_PROVISIONED"
