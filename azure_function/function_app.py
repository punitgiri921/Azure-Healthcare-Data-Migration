import azure.functions as func
import logging
import json
import os
import time
from datetime import datetime, timezone, timedelta
from azure.identity import DefaultAzureCredential
from azure.mgmt.datafactory import DataFactoryManagementClient
from azure.mgmt.datafactory.models import RunFilterParameters, RunQueryFilter
from openai import AzureOpenAI

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

SYSTEM_PROMPT = """
You are the Sentinel Autonomous AI Engine for an Enterprise Azure Healthcare Medallion Lakehouse.
Your responsibility is to analyze pipeline execution telemetry (failures, data drift, security leaks, or healthy runs), and output an autonomous decision.

IMPORTANT RULE:
If the telemetry indicates that the pipeline succeeded with 0 failed activities and watermarks are synchronized, diagnose it as healthy:
- root_cause_category: "NONE_HEALTHY"
- severity: "HEALTHY"
- policy_selected: "NO_ACTION_REQUIRED"
- remediation_actions: [] (empty list)

You must respond ONLY with a valid JSON object strictly matching this schema:
{
  "diagnosis": {
    "root_cause_category": "NONE_HEALTHY | WATERMARK_DESYNC | HIPAA_PII_LEAK | SPARK_TRANSFORMATION_ERROR | GATEWAY_OFFLINE | TRANSIENT_TIMEOUT",
    "severity": "CRITICAL | HIGH | MEDIUM | LOW | HEALTHY",
    "technical_root_cause": "Detailed technical explanation of what caused the failure or confirmation that telemetry is healthy.",
    "affected_medallion_layer": "None | Bronze | Silver | Gold | Serving"
  },
  "autonomous_decision": {
    "policy_selected": "NO_ACTION_REQUIRED | AUTO_HEAL_WATERMARK | ISOLATE_AND_QUARANTINE | RETRY_ACTIVITY | NOTIFY_AND_HALT",
    "rationale": "Why this policy resolves the issue idempotently, or why no action is required.",
    "remediation_actions": [
      {
        "action_type": "EXECUTE_SQL | AZURE_BLOB_MOVE | ADF_RERUN_ACTIVITY | LOG_AUDIT",
        "target": "Specific table, folder, or activity",
        "command_or_payload": "Exact SQL statement, CLI command, or parameter change"
      }
    ],
    "verification_check": "What metric or query confirms success after execution."
  }
}
"""


@app.route(route="sentinel_trigger")
def sentinel_trigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("⚡ [Sentinel Agent] Woken up by Azure Alert Trigger!")

    try:
        alert_body = req.get_json()
    except Exception:
        alert_body = {}

    logging.info(f"Received Alert Payload: {json.dumps(alert_body)[:300]}...")

    # Load configuration
    openai_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    openai_key = os.getenv("AZURE_OPENAI_KEY")
    deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-5-mini")
    api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21")
    sub_id = os.getenv("AZURE_SUBSCRIPTION_ID")
    rg = os.getenv("AZURE_RESOURCE_GROUP", "rg-healthcare-migration-prod")
    adf_name = os.getenv("AZURE_DATA_FACTORY_NAME", "adf-healthcare-punit01")

    # Connect to Azure Data Factory
    credential = DefaultAzureCredential()
    adf_client = DataFactoryManagementClient(credential, sub_id)

    # Query recent pipeline failure
    end_time = datetime.now(timezone.utc) + timedelta(minutes=15)
    start_time = end_time - timedelta(hours=2)

    filter_params = RunFilterParameters(
        last_updated_after=start_time,
        last_updated_before=end_time
    )

    runs = adf_client.pipeline_runs.query_by_factory(rg, adf_name, filter_params)
    sorted_runs = sorted(runs.value, key=lambda r: r.last_updated or r.run_start, reverse=True)

    failed_run = None
    for r in sorted_runs:
        if r.status in ["Failed", "TimedOut"]:
            failed_run = r
            break

    if not failed_run:
        logging.info("No active failure detected in ADF.")
        return func.HttpResponse(
            json.dumps({"status": "HEALTHY", "message": "No failed runs found in lookback window."}),
            mimetype="application/json",
            status_code=200
        )

    # Inspect child activity failures
    activities = adf_client.activity_runs.query_by_pipeline_run(
        resource_group_name=rg,
        factory_name=adf_name,
        run_id=failed_run.run_id,
        filter_parameters=filter_params
    )

    failed_activities = []
    for act in activities.value:
        if act.status == "Failed":
            act_error = act.error if isinstance(act.error, dict) else (act.error.as_dict() if hasattr(act.error, "as_dict") else {})
            failed_activities.append({
                "activity_name": act.activity_name,
                "activity_type": act.activity_type,
                "error_code": act_error.get("errorCode", "Unknown") if isinstance(act_error, dict) else "Unknown",
                "error_message": act_error.get("message", str(act_error)) if isinstance(act_error, dict) else str(act_error)
            })

    incident_context = {
        "pipeline_name": failed_run.pipeline_name,
        "run_id": failed_run.run_id,
        "status": failed_run.status,
        "failed_activities": failed_activities
    }

    logging.info(f"Submitting incident to GPT-5-mini: {json.dumps(incident_context)}")

    # Query Azure OpenAI GPT-5-mini
    openai_client = AzureOpenAI(
        azure_endpoint=openai_endpoint,
        api_key=openai_key,
        api_version=api_version
    )

    prompt = f"Analyze Azure Healthcare Lakehouse incident telemetry:\n{json.dumps(incident_context, indent=2)}"

    response = openai_client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        response_format={"type": "json_object"}
    )

    decision = json.loads(response.choices[0].message.content)
    logging.info(f"AI Decision: {json.dumps(decision)}")

    return func.HttpResponse(
        json.dumps({
            "status": "INCIDENT_PROCESSED",
            "pipeline": failed_run.pipeline_name,
            "run_id": failed_run.run_id,
            "decision": decision
        }),
        mimetype="application/json",
        status_code=200
    )
