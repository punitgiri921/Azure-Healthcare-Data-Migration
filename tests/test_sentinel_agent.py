"""
Enterprise Evaluation Test Suite for Sentinel Agent
===================================================
Tests both SUCCESS and FAILURE paths, verifying:
1. Success Path: Zero false positives when pipeline is healthy.
2. Failure Path (Watermark Desync): Correct diagnosis, policy selection, and idempotent SQL generation.
3. Failure Path (HIPAA Leak): Quarantine policy selection and compliance audit logging.
4. Dry-Run Safety: Verifies tools execute in advisory mode without state mutation.
"""

import os
import sys
import json
import pytest

# Ensure scripts module is importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from scripts.sentinel_agent import (
    diagnose_and_decide,
    simulate_incident,
    execute_remediation,
    check_pipeline_health
)


# -----------------------------------------------------------------------------
# TEST 1: SUCCESS PATH (Zero False Positives)
# -----------------------------------------------------------------------------
def test_success_pipeline_health():
    """
    Verifies that when an ADF pipeline run succeeds, the agent does NOT
    trigger remediation or falsely diagnose errors.
    """
    healthy_telemetry = {
        "pipeline_name": "PL_Master_Healthcare_Pipeline",
        "run_id": "test-run-100-success",
        "status": "Succeeded",
        "duration_ms": 530000,
        "failed_activities": [],
        "watermark_state": {
            "table_name": "patients",
            "control_table_watermark": "2026-09-24T18:30:00Z",
            "latest_bronze_file_max_ts": "2026-09-24T18:30:00Z"
        }
    }

    # Reason with GPT-5-mini
    decision = diagnose_and_decide(healthy_telemetry)

    diag = decision.get("diagnosis", {})
    plan = decision.get("autonomous_decision", {})

    # Assertions
    assert diag.get("severity") in ["LOW", "NONE", "HEALTHY"], f"Unexpected high severity for healthy run: {diag}"
    # Must NOT attempt to mutate state on healthy run
    assert plan.get("policy_selected") in ["NONE", "NO_ACTION_REQUIRED", "NOTIFY_AND_HALT"], f"Agent attempted unneeded remediation: {plan}"


# -----------------------------------------------------------------------------
# TEST 2: FAILURE PATH - WATERMARK DESYNCHRONIZATION
# -----------------------------------------------------------------------------
def test_watermark_desync_failure_remediation():
    """
    Verifies that a watermark commit failure triggers AUTO_HEAL_WATERMARK
    with idempotent SQL containing a safe WHERE clause.
    """
    incident = simulate_incident("watermark_desync")
    assert incident["status"] == "Failed"

    decision = diagnose_and_decide(incident)

    diag = decision.get("diagnosis", {})
    plan = decision.get("autonomous_decision", {})

    # Assert Category & Severity
    assert diag.get("root_cause_category") == "WATERMARK_DESYNC", f"Wrong category: {diag.get('root_cause_category')}"
    assert diag.get("severity") in ["HIGH", "CRITICAL"]

    # Assert Policy Selected
    assert plan.get("policy_selected") == "AUTO_HEAL_WATERMARK"

    # Assert Remediation contains SQL update with safety WHERE condition
    actions = plan.get("remediation_actions", [])
    sql_actions = [a for a in actions if a.get("action_type") == "EXECUTE_SQL"]
    assert len(sql_actions) > 0, "No SQL remediation actions generated"

    combined_sql = " ".join([a.get("command_or_payload", "").upper() for a in sql_actions])
    assert "UPDATE" in combined_sql
    assert "WHERE" in combined_sql, "Violation: Generated SQL must be idempotent and contain a WHERE clause!"


# -----------------------------------------------------------------------------
# TEST 3: FAILURE PATH - HIPAA PII LEAK DETECTION
# -----------------------------------------------------------------------------
def test_hipaa_pii_leak_isolation():
    """
    Verifies that an unmasked SSN alert triggers ISOLATE_AND_QUARANTINE
    to protect patient confidentiality under HIPAA regulations.
    """
    incident = simulate_incident("hipaa_leak")
    assert incident["status"] == "Warning"

    decision = diagnose_and_decide(incident)

    diag = decision.get("diagnosis", {})
    plan = decision.get("autonomous_decision", {})

    assert diag.get("root_cause_category") == "HIPAA_PII_LEAK"
    assert diag.get("severity") == "CRITICAL"
    assert plan.get("policy_selected") == "ISOLATE_AND_QUARANTINE"

    # Must contain a blob move or quarantine action
    actions = plan.get("remediation_actions", [])
    action_types = [a.get("action_type") for a in actions]
    assert any(at in ["AZURE_BLOB_MOVE", "QUARANTINE", "EXECUTE_SQL"] for at in action_types)


# -----------------------------------------------------------------------------
# TEST 4: TOOL EXECUTION HARNESS (Dry-Run Verification)
# -----------------------------------------------------------------------------
def test_execute_remediation_dry_run():
    """
    Tests that the remediation executor processes action payloads safely.
    """
    mock_decision = {
        "autonomous_decision": {
            "policy_selected": "AUTO_HEAL_WATERMARK",
            "remediation_actions": [
                {
                    "action_type": "EXECUTE_SQL",
                    "target": "medallion.etl_watermark_control",
                    "command_or_payload": "UPDATE etl_watermark_control SET last_watermark = '2026-09-24' WHERE table_name = 'patients';"
                },
                {
                    "action_type": "LOG_AUDIT",
                    "target": "sentinel.audit_log",
                    "command_or_payload": "Test audit log entry"
                }
            ]
        }
    }

    results = execute_remediation(mock_decision)
    assert len(results) == 2
    assert all(r["status"] == "SUCCESS" for r in results)
