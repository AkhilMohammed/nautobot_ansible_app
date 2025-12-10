#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"        # standalone or ha
ENVIRONMENT="${2:-}" # dev or prod

if [[ -z "$MODE" || -z "$ENVIRONMENT" ]]; then
  echo "Usage: $0 <standalone|ha> <dev|prod>"
  exit 1
fi

cd "$(dirname "$0")/.."

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install ansible

# Optional: use Ansible collections
ansible-galaxy collection install community.docker kubernetes.core community.kubernetes

case "$MODE" in
  standalone)
    INVENTORY="inventory/vm/${ENVIRONMENT}.yml"
    PLAYBOOK="playbooks/deploy_vm_all.yml"
    ;;
  ha)
    INVENTORY="inventory/k8s/${ENVIRONMENT}.yml"
    PLAYBOOK="playbooks/deploy_k8s_all.yml"
    ;;
  *)
    echo "Unknown mode: $MODE (expected standalone or ha)"
    exit 1
    ;;
esac

# Use SSH key or passwordless sudo in target envs; no interactive prompts in CI.
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" \
  -e "deploy_env=${ENVIRONMENT}"
