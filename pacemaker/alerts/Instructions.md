## Setting up Cluster Alerts

> We don't need to create sender email in email server. We can whitelist the cluster or node IPs in the mail server.

### Step 1: Install mailx
    dnf install mailx -y

### Step 2: Download the script `pacemaker_mail_alert.sh` or copy the script to `/usr/local/bin`

### Step 3: Make the script executable
    chmod +x /usr/local/bin/pacemaker_mail_alert.sh

### Step 4: Create the alert
    pcs alert create id=custom_mail_alert path=/usr/local/bin/pacemaker_mail_alert.sh

### Step 5: Add alert recipient
    pcs alert recipient add custom_mail_alert id=admin_recipient value=system@rhel-ha.lan
