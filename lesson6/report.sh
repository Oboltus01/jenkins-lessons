#!/usr/bin/env bash
set -euo pipefail

PASS=$(cat /root/.jenkins-lesson5-fast/admin-password)
BASE="http://localhost:8080"

get() {
    curl -gfsS -u "admin:$PASS" "$BASE$1"
}

status() {
    get "/job/$1/lastBuild/api/json?tree=number,result" |
        python3 -c 'import json,sys; d=json.load(sys.stdin); print("Build #{}: {}".format(d["number"],d["result"]))'
}

echo "=================================================="
echo "   JENKINS LESSON 6 - FINAL PRACTICE REPORT"
echo "=================================================="

echo ""
echo "[1] CAPSTONE - HOURS 9-10"
status "lesson6-capstone-pipeline"
get "/job/lesson6-capstone-pipeline/ws/dist/release.json"
echo ""

echo ""
echo "[2] MD5 CHECKSUMS - HOURS 7-8"
status "lesson6-artifact-demo"
get "/job/lesson6-artifact-demo/lastBuild/consoleText" |
    grep -E 'MD5 verification passed|Archiving artifacts|Recording fingerprints|Finished:'
echo "Archived files:"
get "/job/lesson6-artifact-demo/lastBuild/api/json?tree=artifacts[fileName]" |
    python3 -c 'import json,sys; print(", ".join(x["fileName"] for x in json.load(sys.stdin)["artifacts"]))'

echo ""
echo "[3] LAB ARTIFACT VERIFIER"
status "lab-artifact-verifier"
get "/job/lab-artifact-verifier/lastBuild/consoleText" |
    grep -E 'Artifact verification successful|LAB-TEARDOWN|Finished:'
echo "Manifest:"
get "/job/lab-artifact-verifier/ws/build_out/manifest.json"
echo ""

echo ""
echo "=================================================="
echo "        END OF LESSON 6 REPORT"
echo "=================================================="
