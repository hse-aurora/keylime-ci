#!/usr/bin/env bash

sudo tee /etc/skel/.bashrc > /dev/null <<'EOF'

alias sudo="sudo " # Allows aliases to be executed using sudo
alias keylime_tenant="docker run -it --rm --name keylime_tenant --net keylime-net -v kl-data-vol:/var/lib/keylime -v kl-vrt-config-vol:/etc/keylime -v kl-vrt-src-vol:/usr/local/src/keylime gcr.io/project-keylime/keylime_tenant:stage-a"
alias klrebuild="docker exec -it keylime_agent /bin/bash -c "cd /usr/local/src/rust-keylime; make; install -D -t /usr/bin target/debug/keylime_agent; install -D -t /usr/bin target/debug/keylime_ima_emulator""

function klrestart {
  if [[ $@ == "v" ]]; then
    docker restart keylime_verifier
  elif [[ $@ == "r" ]]; then
    docker restart keylime_registrar
  elif [[ $@ == "a" ]]; then
    docker restart keylime_agent
  else
    echo "Invalid argument. Usage: klrestart <component> where <component> is 'v', 'r' or 'a'."
  fi
}
EOF