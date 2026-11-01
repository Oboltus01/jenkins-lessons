#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8080"
PASS_FILE="/root/.jenkins-lesson5-fast/admin-password"
[[ -s "$PASS_FILE" ]] || { echo "[ERROR] Jenkins password file missing" >&2; exit 1; }
PASS=$(cat "$PASS_FILE")
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

get() {
    curl -gfsS --max-time 15 -u "admin:$PASS" "$BASE$1"
}
build_status() {
    local job="$1" number="$2"
    get "/job/$job/$number/api/json?tree=number,building,result" |
        python3 -c 'import json,sys; v=json.load(sys.stdin); print("Build #{}: {}".format(v["number"],v.get("result") or "IN_PROGRESS")); sys.exit(1 if v.get("building") else 0)'
}
expect_status() {
    local job="$1" number="$2" expected="$3" actual
    actual=$(get "/job/$job/$number/api/json?tree=result,building" |
      python3 -c 'import json,sys; d=json.load(sys.stdin); print("IN_PROGRESS" if d.get("building") else d.get("result") or "UNKNOWN")')
    [[ "$actual" == "$expected" ]] || {
        echo "[ERROR] $job #$number: expected $expected, got $actual" >&2
        return 1
    }
}
heading() {
    printf '\n==================================================\n%s\n==================================================\n' "$1"
}

heading "JENKINS LESSON 7 - FINAL PRACTICE REPORT"

heading "[1] RETRY & EXPONENTIAL BACKOFF - HOURS 5-6"
build_status lesson7-parallel-demo 1
expect_status lesson7-parallel-demo 1 SUCCESS
get "/job/lesson7-parallel-demo/1/consoleText" |
    grep -E '\[ATTEMPT|\[BACKOFF|\[RETRY SUCCESS|Finished:'

heading "[2] MULTI-STAGE FALLBACK - HOURS 7-8"
build_status lesson7-parallel-demo 2
expect_status lesson7-parallel-demo 2 SUCCESS
get "/job/lesson7-parallel-demo/2/consoleText" |
    grep -E 'Primary region deployment failed|FALLBACK ACTIVATED|FALLBACK SUCCESS|Finished:'
echo "Deployment manifest (current workspace):"
get "/job/lesson7-parallel-demo/ws/build_out/deployment.json" |
    python3 -m json.tool

heading "[3] CAPSTONE - SUCCESS & FAILURE SCENARIOS"
build_status lesson7-capstone-pipeline 1
expect_status lesson7-capstone-pipeline 1 SUCCESS
build_status lesson7-capstone-pipeline 2
expect_status lesson7-capstone-pipeline 2 FAILURE
get "/job/lesson7-capstone-pipeline/2/consoleText" |
    grep -E 'SYNC FAILURE|FALLBACK|Finished:'
echo "Emergency manifest (current workspace):"
get "/job/lesson7-capstone-pipeline/ws/build_out/emergency.json" |
    python3 -m json.tool

heading "[4] AUDIT AGGREGATOR"
build_status lesson7-audit-aggregator 1
expect_status lesson7-audit-aggregator 1 SUCCESS
get "/job/lesson7-audit-aggregator/1/consoleText" |
    grep -E 'SYNC SUCCESS|AUDIT SUCCESS|CLEANUP|Finished:'
echo "Audit manifest:"
get "/job/lesson7-audit-aggregator/ws/build_out/audit_summary.json"     > "$WORKDIR/audit_summary.json"
python3 -m json.tool "$WORKDIR/audit_summary.json"
get "/job/lesson7-audit-aggregator/ws/build_out/audit_summary.json.md5"     > "$WORKDIR/audit_summary.json.md5"
echo "MD5 verification of downloaded manifest:"
(cd "$WORKDIR" && md5sum -c audit_summary.json.md5)

heading "LESSON 7 REPORT: ALL CHECKS PASSED"
echo "Note: /ws/ contains the current workspace, not immutable per-build artifacts."
