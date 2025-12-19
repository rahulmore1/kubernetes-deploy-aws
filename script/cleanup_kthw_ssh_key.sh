#!/usr/bin/env bash
set -euo pipefail
# Cleanup KTHW SSH key from known_hosts

KEY_PATH="${HOME}/.ssh/id_ed25519_kthw"
PUB_PATH="${KEY_PATH}.pub"

echo "KTHW SSH key cleanup"
echo "Target private key : ${KEY_PATH}"
echo "Target public key  : ${PUB_PATH}"
echo

# Check if files exist
missing=true
if [[ -f "${KEY_PATH}" ]]; then
  echo "Found private key: ${KEY_PATH}"
  missing=false
else
  echo "Private key not found: ${KEY_PATH}"
fi

if [[ -f "${PUB_PATH}" ]]; then
  echo "found public key : ${PUB_PATH}"
  missing=false
else
  echo "Public key not found: ${PUB_PATH}"
fi

if [[ "${missing}" == true ]]; then
  echo
  echo "Nothing to delete: neither file exists."
else
  echo
fi

# Show keys currently loaded in ssh-agent (if any)
echo " Checking ssh-agent for loaded keys"
if ssh-add -l >/dev/null 2>&1; then
  echo "Currently loaded keys:"
  ssh-add -l || true
else
  echo "No keys currently loaded in ssh-agent or agent not running."
fi

echo
read -r -p "Proceed with deleting the files above and removing this key from ssh-agent? [y/N]: " ANSWER
case "${ANSWER}" in
  y|Y|yes|YES)
    echo
    echo "Removing key from ssh-agent (if loaded)..."
    if ssh-add -d "${KEY_PATH}" >/dev/null 2>&1; then
      echo " Key removed from ssh-agent cache: ${KEY_PATH}"
    else
      echo "ℹ  Key not found in ssh-agent (or ssh-agent not running)."
    fi

    echo
    echo " Deleting key files..."
    if [[ -f "${KEY_PATH}" ]]; then
      rm -f "${KEY_PATH}"
      echo "Deleted: ${KEY_PATH}"
    fi

    if [[ -f "${PUB_PATH}" ]]; then
      rm -f "${PUB_PATH}"
      echo " Deleted: ${PUB_PATH}"
    fi

    echo
    echo " Cleanup complete."
    ;;
  *)
    echo
    echo " Cleanup cancelled. No changes made."
    ;;
esac

echo "reminder: if you referenced this key in ~/.ssh/config (e.g. a Host for KTHW),"
echo "you may also want to edit that file and remove or update that Host entry."