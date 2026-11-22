#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://localhost:8080"
NODE="pt1-ephemeral-node"

api() {
    curl -fsS -g "$JENKINS_URL$1"
}

groovy() {
    curl -fsS -X POST "$JENKINS_URL/scriptText" \
        --data-urlencode "script=$1"
}

echo "=== PT1: EPHEMERAL AGENT LIFECYCLE ==="

echo
echo "[1] IDEMPOTENT REGISTRATION"

REGISTER_SCRIPT=$(cat <<'GROOVY'
import jenkins.model.Jenkins
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher
import hudson.model.Node

def j = Jenkins.get()
def name = "pt1-ephemeral-node"

if (j.getNode(name) == null) {
    def node = new DumbSlave(
        name,
        "/tmp/pt1-ephemeral-node",
        new JNLPLauncher(true)
    )
    node.setNumExecutors(3)
    node.setMode(Node.Mode.EXCLUSIVE)
    node.setLabelString("tier-gold eu-west")
    j.addNode(node)
    println "CREATED: ${name}"
} else {
    println "EXISTS: ${name}"
}
GROOVY
)

groovy "$REGISTER_SCRIPT"
groovy "$REGISTER_SCRIPT"

echo
echo "[2] REST FLEET AUDIT"

api "/computer/$NODE/api/json?tree=displayName,numExecutors,assignedLabels[name]" \
    | python3 -m json.tool

echo
echo "[3] IDEMPOTENT QUARANTINE"

STATE=$(api "/computer/$NODE/api/json?tree=temporarilyOffline" |
    python3 -c 'import json,sys; print(str(json.load(sys.stdin)["temporarilyOffline"]).lower())')

if [ "$STATE" = "false" ]; then
    curl -fsS -X POST \
        --data-urlencode "offlineMessage=PT1 Audit Lock" \
        "$JENKINS_URL/computer/$NODE/toggleOffline"
    echo "CORDONED: $NODE"
else
    echo "ALREADY CORDONED: $NODE"
fi

api "/computer/$NODE/api/json?tree=temporarilyOffline,offlineCauseReason" \
    | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["temporarilyOffline"] is True
assert "PT1 Audit Lock" in d["offlineCauseReason"]
print("QUARANTINE VERIFIED:",d["offlineCauseReason"])
'

echo
echo "[4] GRACEFUL DECOMMISSIONING"

groovy '
import jenkins.model.Jenkins

def j = Jenkins.get()
def node = j.getNode("pt1-ephemeral-node")

if (node != null) {
    if (node.toComputer()?.isIdle()) {
        j.removeNode(node)
        println "REMOVED: pt1-ephemeral-node"
    } else {
        throw new IllegalStateException("Node is busy")
    }
}
'

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$JENKINS_URL/computer/$NODE/api/json")

echo "AFTER REMOVAL HTTP STATUS: $HTTP_CODE"

if [ "$HTTP_CODE" != "404" ]; then
    echo "[FAIL] Node still exists!"
    exit 1
fi

echo
echo "[SUCCESS] PRACTICE TEST 1 PASSED"
