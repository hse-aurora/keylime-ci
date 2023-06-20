#!/usr/bin/env bash

# Add startup script to set a banner to be displayed on the login screen communicating connection options:

sudo tee /etc/rc.d/rc.local > /dev/null <<'EOF'
#!/usr/bin/env bash

sleep 3 # Wait for DHCP

msg=""
host=$(hostname -s)
ips=($(hostname -I))
main_ip="${ips[0]}"

msg+=$'\\S\n'
msg+=$'Kernel \\r on an \\m (\\l)\n'

msg+=$'\n'
msg+="─────────────────────────────────────────────────────────────────────────────────────────"$'\n'
msg+=" » $host"$'\n'
msg+=$'\n'

if [ -f /etc/rc.d/prevrun ]; then
  msg+=" Connect to this VM via:"$'\n'
  msg+=$'\n'
  msg+=" 1) SSH     : From a remote machine, run \`ssh user@$main_ip\`."$'\n'
  msg+=$'\n'
  msg+=" 2) VS Code : Click the blue ›‹ icon in the bottom-left corner of an open window."$'\n'
  msg+="              Choose the \"Connect to Host... (Remote-SSH)\" option."$'\n'
  msg+="              At the prompt, type \"user@$main_ip\" and press Enter."$'\n'
else
  msg+=" Connect to this VM via SSH by running \`ssh user@$main_ip\` from a remote machine."$'\n'
fi

msg+="═════════════════════════════════════════════════════════════════════════════════════════"$'\n'
msg+=$'\n'

echo "$msg" > /etc/issue

touch /etc/rc.d/prevrun

exit 0
EOF

sudo chmod 755 /etc/rc.d/rc.local

# Add a login script to display a banner after successful authentication:

sudo tee /etc/profile.d/01_display-login-banner.sh > /dev/null <<'EOF'
#!/usr/bin/env bash

username=$(whoami)
host=$(hostname -s)
ips=($(hostname -I))
main_ip="${ips[0]}"

if [ -n "$SSH_CLIENT" ]; then
  echo
  echo "──ℹ️─────────────────────────────────────────────────────────────────────────────────────"
  echo "     Welcome $username to $host"
  echo
  echo "     You can also connect to this VM from VS Code:"
  echo "       1. Click the blue ›‹ icon in the bottom-left corner of an open window."
  echo "       2. Choose the \"Connect to Host... (Remote-SSH)\" option."
  echo "       3. At the prompt, type \"$username@$main_ip\" and press Enter."
else
  echo "─────────────────────────────────────────────────────────────────────────────────────────"
  echo "   » Welcome $username to $host"
fi

echo "═════════════════════════════════════════════════════════════════════════════════════════"
echo
EOF

sudo chmod 755 /etc/profile.d/01_display-login-banner.sh