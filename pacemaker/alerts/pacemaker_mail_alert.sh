#!/bin/sh

# --- Configuration ---
smtp_server="192.168.190.249"
email_sender="hacluster@rhel-ha.lan"

# --- EARLY EXIT FILTERS ---
# 1. Stop "monitor: ok" spam (Successful recurring health checks)
if [ "$CRM_alert_task" = "monitor" ] && [ "$CRM_alert_desc" = "ok" ]; then
    exit 0
fi

# 2. Stop "monitor: Cancelled" spam (Background timer cancellation)
if [ "$CRM_alert_task" = "monitor" ] && [ "$CRM_alert_desc" = "Cancelled" ]; then
    exit 0
fi

# --- Clean Email Body ---
# ADDED "Operation" line so you know if it was a start or stop
email_body=$(cat <<REPORT_END
Cluster Event Report
===================================
Event           : ${CRM_alert_kind}
Node            : ${CRM_alert_node}
Resource        : ${CRM_alert_rsc}
Operation       : ${CRM_alert_task}
Result                  : ${CRM_alert_desc}
Timestamp     : ${CRM_alert_timestamp}

(Exit Code: ${CRM_alert_rc})
REPORT_END
)

# --- Subject Line Logic ---
node_name=$(uname -n)
cluster_name=$(crm_attribute --query -n cluster-name -q 2>/dev/null || echo "Cluster")

if [ -z "${CRM_alert_version}" ]; then
    email_subject="Pacemaker Alert (Unknown Version)"
else
    case ${CRM_alert_kind} in
        node)
            email_subject="${cluster_name}: Node '${CRM_alert_node}' is now '${CRM_alert_desc}'"
            ;;
        fencing)
            email_subject="${cluster_name}: Fencing ${CRM_alert_desc}"
            ;;
        resource)
            # UPDATED: Now includes the TASK (start/stop) and the RESULT (ok/failed)
            # Format: "Resource 'web_fs': start ok" or "stop ok"

            if [ "${CRM_alert_interval}" != "0" ] && [ -n "${CRM_alert_interval}" ]; then
                 interval_info=" (${CRM_alert_interval})"
            fi

            email_subject="${cluster_name}: Resource '${CRM_alert_rsc}' on '${CRM_alert_node}': ${CRM_alert_task} ${CRM_alert_desc}${interval_info}"
            ;;
        attribute)
            email_subject="${cluster_name}: Attribute '${CRM_alert_attribute_name}' on '${CRM_alert_node}' changed"
            ;;
        *)
            email_subject="${cluster_name}: Unhandled $CRM_alert_kind alert"
            ;;
    esac
fi

# --- Send Email ---
if [ -n "${email_subject}" ]; then
    echo "${email_body}" | mailx -S smtp="${smtp_server}" \
         -r "${email_sender}" \
         -s "${email_subject}" \
         "${CRM_alert_recipient}"
fi
