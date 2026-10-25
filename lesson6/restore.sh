#!/usr/bin/env bash
set -euo pipefail
# Restore Lesson 6 job in an existing Jenkins lab with admin password stored by lesson5/fast-setup.sh.
BASE="http://localhost:8080"
PASS_FILE="/root/.jenkins-lesson5-fast/admin-password"
[ -s "$PASS_FILE" ] || { echo "First install Jenkins with lesson5/fast-setup.sh" >&2; exit 1; }
PASS=$(cat "$PASS_FILE")
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/provision.groovy -o "$TMPDIR/provision.groovy"
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/validation.groovy -o "$TMPDIR/validation.groovy"
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/checksums.groovy -o "$TMPDIR/checksums.groovy"
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/capstone_provision.groovy -o "$TMPDIR/capstone_provision.groovy"
curl -fsSL https://raw.githubusercontent.com/Oboltus01/jenkins-lesson-2/lesson-structure/lesson6/lab_artifact_verifier.groovy -o "$TMPDIR/lab_artifact_verifier.groovy"

get_crumb() {
  curl -fsS -u "admin:$PASS" -c "$TMPDIR/cookies" -b "$TMPDIR/cookies" "$BASE/crumbIssuer/api/json" |
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["crumbRequestField"] + ": " + d["crumb"])'
}
CRUMB=$(get_crumb)

deploy() {
  local file=$1 expected=$2 response
  response=$(curl -fsS -u "admin:$PASS" -b "$TMPDIR/cookies" -H "$CRUMB" \
    --data-urlencode "script@$file" "$BASE/scriptText")
  printf '%s\n' "$response"
  grep -Fq "$expected" <<< "$response" || { echo "Provisioning did not report success" >&2; exit 1; }
}
# Apply sequentially; final artifact-demo configuration is Hours 7-8.
deploy "$TMPDIR/provision.groovy" "LESSON6_HOURS1_2_PROVISIONED"
deploy "$TMPDIR/validation.groovy" "LESSON6_HOURS3_4_PROVISIONED"
deploy "$TMPDIR/checksums.groovy" "LESSON6_HOURS7_8_PROVISIONED"
deploy "$TMPDIR/capstone_provision.groovy" "LESSON6_CAPSTONE_PROVISIONED"
deploy "$TMPDIR/lab_artifact_verifier.groovy" "LAB_ARTIFACT_VERIFIER_PROVISIONED"

curl -gfsS -u "admin:$PASS" \
  "$BASE/job/lesson6-artifact-demo/api/json?tree=name,buildable,nextBuildNumber" |
  python3 -m json.tool

for job in lesson6-capstone-pipeline lab-artifact-verifier; do
  curl -gfsS -u "admin:$PASS" "$BASE/job/$job/api/json?tree=name,buildable,nextBuildNumber" | python3 -m json.tool
done

echo "Restored all Lesson 6 jobs. No builds triggered; existing history preserved."
