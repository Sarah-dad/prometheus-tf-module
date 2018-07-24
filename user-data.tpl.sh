#!/bin/bash

set -e

GITLAB_TOKEN=${gitlab_token}
ANSIBLE_TAG=${ansible_tag}

yum upgrade -y
yum install -y git ansible

git clone https://oauth2:$GITLAB_TOKEN@git.renault-digital.com/system0/ansible-roles/monitor.git

cd monitor && ansible-playbook -l $ANSIBLE_TAG -i inventory install.yml

