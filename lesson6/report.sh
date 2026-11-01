#!/usr/bin/env bash
set -euo pipefail

PASS_FILE="/root/.jenkins-lesson5-fast/admin-password"
[ -s "$PASS_FILE" ] || { echo "Missing Jenkins password file: $PASS_FILE" >&2; exit 1; }
PASS=$(cat "$PASS_FILE")
BASE="http://localhost:8080"

get() {
    # -g / --globoff is mandatory when Jenkins tree=... contains [brackets].
    curl -gfsS -u "admin:$PASS" "$BASE$1"
}

status() {
    get "/job/$1/lastBuild/api/json?tree=number,building,result" |
        python3 -c 'import json,sys; d=json.load(sys.stdin); print("Build #{}: {}{}".format(d["number"],d.get("result") or "NOT_FINISHED", " (running)" if d.get("building") else "")); sys.exit(0 if d.get("result") == "SUCCESS" and not d.get("building") else 1)'
}

echo "=================================================="
echo "   JENKINS LESSON 6 - FINAL PRACTICE REPORT"
echo "=================================================="

echo ""
echo "[1] CAPSTONE - HOURS 9-10"
status "lesson6-capstone-pipeline"
echo "Release manifest (current workspace):"
get "/job/lesson6-capstone-pipeline/ws/dist/release.json"
echo ""

echo ""
echo "[2] MD5 CHECKSUMS - HOURS 7-8"
status "lesson6-artifact-demo"
get "/job/lesson6-artifact-demo/lastBuild/consoleText" |
    grep -E 'MD5 verification passed|Archiving artifacts|Recording fingerprints|Finished:'
echo "Archived files (last build):"
get "/job/lesson6-artifact-demo/lastBuild/api/json?tree=artifacts[fileName]" |
    python3 -c 'import json,sys; print(", ".join(x["fileName"] for x in json.load(sys.stdin).get("artifacts", [])))'

echo ""
echo "[3] LAB ARTIFACT VERIFIER"
status "lab-artifact-verifier"
get "/job/lab-artifact-verifier/lastBuild/consoleText" |
    grep -E 'Artifact verification successful|LAB-TEARDOWN|Finished:'
echo "Manifest (current workspace):"
get "/job/lab-artifact-verifier/ws/build_out/manifest.json"
echo ""

echo ""
echo "=================================================="
echo "        END OF LESSON 6 REPORT"
echo "=================================================="
