#!/bin/sh

# --- Configuration ---
smtp_server="192.168.190.249"
email_sender="hacluster@rhel-ha.lan"
log_file="/var/log/pacemaker_events.log"
enable_logging="true"

# --- 1. NOISE FILTERING ---
# Filter out successful monitor checks to prevent flooding
if [ "$CRM_alert_task" = "monitor" ] && [ "$CRM_alert_desc" = "ok" ]; then
    exit 0
fi
if [ "$CRM_alert_task" = "monitor" ] && [ "$CRM_alert_desc" = "Cancelled" ]; then
    exit 0
fi

# --- 2. STRICT STATUS LOGIC ---
# Requirement: Stop=[ALERT], Start=[OK], No [INFO]

# Default everything to ALERT first
status_tag="[ALERT]"
severity="CRITICAL"

# Check for Success cases that deserve [OK]
if [ "${CRM_alert_kind}" = "node" ] && [ "${CRM_alert_desc}" = "member" ]; then
    status_tag="[OK]"
    severity="RECOVERED"
elif [ "${CRM_alert_desc}" = "ok" ]; then
    # Resource operations that are OK
    if [ "${CRM_alert_task}" = "start" ] || [ "${CRM_alert_task}" = "promote" ]; then
        status_tag="[OK]"
        severity="RECOVERED"
    fi
fi

# --- 3. CONSTRUCT SUBJECT LINE ---
node_name=$(uname -n)
cluster_name=$(crm_attribute --query -n cluster-name -q 2>/dev/null || echo "Cluster")
rsc_name="${CRM_alert_rsc:-UnknownResource}"
task_cap="$(echo ${CRM_alert_task} | cut -c1 | tr '[a-z]' '[A-Z]')$(echo ${CRM_alert_task} | cut -c2-)"

if [ "${CRM_alert_kind}" = "resource" ]; then
    if [ "$status_tag" = "[ALERT]" ] && [ "${CRM_alert_desc}" != "ok" ]; then
        # Actual failure
        email_subject="${status_tag}: ${rsc_name} (${task_cap} ${CRM_alert_desc}) - ${CRM_alert_node}"
    else
        # Stop (Alert) or Start (OK)
        email_subject="${status_tag}: ${rsc_name} (${task_cap}) - ${CRM_alert_node}"
    fi
elif [ "${CRM_alert_kind}" = "node" ]; then
    email_subject="${status_tag}: Node ${CRM_alert_desc} - ${CRM_alert_node} - ${cluster_name}"
elif [ "${CRM_alert_kind}" = "fencing" ]; then
    email_subject="${status_tag}: Fencing Action (${CRM_alert_desc}) - ${CRM_alert_node}"
else
    email_subject="${status_tag}: ${cluster_name} - ${CRM_alert_kind} event"
fi

# --- 4. PREPARE EMAIL BODY (ALIGNED) ---
# I have added spaces to the labels below to ensure the colons align perfectly.
email_body=$(cat <<REPORT_END
EVENT STATUS : ${status_tag}
--------------------------------------------------
Resource     : ${CRM_alert_rsc}
Operation    : ${CRM_alert_task}
Result       : ${CRM_alert_desc}
Node         : ${CRM_alert_node}
Cluster      : ${cluster_name}
Timestamp    : ${CRM_alert_timestamp}
Exit Code    : ${CRM_alert_rc}
--------------------------------------------------
REPORT_END
)

# --- 5. LOGGING ---
if [ "$enable_logging" = "true" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${status_tag} Node:${CRM_alert_node} Rsc:${CRM_alert_rsc} Op:${CRM_alert_task} Result:${CRM_alert_desc}" >> "$log_file"
fi

# --- 6. SEND EMAIL ---
if [ -n "${email_subject}" ]; then
    echo "${email_body}" | mailx -S smtp="${smtp_server}" \
         -r "${email_sender}" \
         -s "${email_subject}" \
         "${CRM_alert_recipient}"
fi
