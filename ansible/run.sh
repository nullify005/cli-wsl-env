#!/bin/bash

set -ex
RUN_DIR="/opt/ansible"
USERNAME="${1}"
if [ ! -x ${RUN_DIR} ]; then mkdir -p ${RUN_DIR}; fi
cp -Rvp . $RUN_DIR
chmod -R og-rwx $RUN_DIR
cd $RUN_DIR
ansible-playbook playbooks/main.yml -v --extra-vars username=$USERNAME
