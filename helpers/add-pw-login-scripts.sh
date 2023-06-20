#!/usr/bin/env bash

# Add script to /usr/local/bin to detect when the user does not have a password set and
# prompt the user to choose a new one
sudo tee /usr/local/bin/setuserpw > /dev/null <<'EOF'
#!/usr/bin/env bash

user_info=($(who am i))
username="${user_info[0]}"

pw_info=($(passwd --status $username 2> /dev/null))

new_pw=""
function prompt_for_pw {
  echo -n "New password: "
  read -s pw1
  echo
  echo -n "Again: "
  read -s pw2
  echo

  if [ "$pw1" == "$pw2" ]; then
    new_pw="$pw1"
  fi
}

if [ "${#pw_info[@]}" -eq 0 ]; then
  exit 3
fi

if [[ "${pw_info[1]}" == "PS" ]]; then
  exit 2
fi

echo
echo "──⚠️─────────────────────────────────────────────────"
echo "     No password set for $username!"
echo "     Please enter a password of your choice below."
echo "═════════════════════════════════════════════════════"
echo

for i in {1..3}; do
  prompt_for_pw

  if [[ "$new_pw" != "" ]]; then
    echo "$username:$new_pw" | chpasswd

    if [[ "$?" == 0 ]]; then
      echo
      echo "Password for $username changed successfully!"
      exit 0
    else
      echo "Could not change password. Check whether it meets the complexity requirements."
      echo
    fi
  else
    echo "Passwords did not match."
    echo
  fi
done

exit 1
EOF

sudo chmod 755 /usr/local/bin/setuserpw

# Allow the above script to be run with sudo without a password
if ! sudo grep -q "NOPASSWD: /usr/local/bin/setuserpw" "/etc/sudoers"; then
  echo "%wheel  ALL=(root)      NOPASSWD: /usr/local/bin/setuserpw" | sudo EDITOR="tee -a" visudo > /dev/null
fi

# Add login script to invoke the change passsword script on user login
sudo tee /etc/profile.d/00_checkuserpw.sh > /dev/null <<'EOF'
#!/usr/bin/env bash

sudo setuserpw
EOF

sudo chmod 755 /etc/profile.d/00_checkuserpw.sh