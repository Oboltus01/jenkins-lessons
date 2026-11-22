# Jenkins Lesson 11 — Corporate Orchestration

Date: 2026-11-22
Instructor: Sergey
Environment: Killercoda Ubuntu 24.04, Docker, Jenkins LTS JDK17

## Practice Test 1 — Ephemeral Agent Lifecycle
Script: pt1_fleet_lifecycle.sh
Result: PASSED

- Idempotent agent registration
- REST API fleet audit
- Agent quarantine
- Graceful decommissioning
- HTTP 404 verification

## Practice Test 2 — Queue Failover
Script: pt2_queue_failover.sh
Result: PASSED

- Offline agent detection
- Stalled queue inspection
- Dynamic label reassignment
- Successful build on built-in node
- Artifact verification

## Challenge 1 — Admission Controller
Script: lesson11_challenge1_admission.sh
Result: PASSED

- Three batch jobs submitted
- Queue depth reached 2
- Fourth batch rejected
- Three successful builds
- Original executor capacity restored

## Challenge 2 — Quarantine & Rebalance
Script: lesson11_challenge2_quarantine.sh
Result: PASSED

- Worker pool configuration
- Automated node quarantine
- Successful failover to built-in
- Placement artifact verification
- Agent and label cleanup

## Final Results

All four assignments completed successfully.

Source:
https://github.com/sirgray/specter-jen/blob/21921db92cee2f9b002bd73d47adc5b34c1821b5/lesson11.md
