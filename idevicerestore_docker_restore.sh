#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/libimobiledevice/idevicerestore.git"
REPO_DIR="idevicerestore"
DOCKER_SUBDIR="docker"

# Remember where we started so cleanup can safely remove the repo directory.
START_DIR="$(pwd)"

# Default restore args (matches your screenshot).
# You can override by passing args to this script, e.g.:
#   ./idevicerestore_docker_restore.sh --latest
#   ./idevicerestore_docker_restore.sh --erase --latest
RUN_ARGS=("$@")
if [[ ${#RUN_ARGS[@]} -eq 0 ]]; then
  RUN_ARGS=(--erase --latest)
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

need_cmd git
need_cmd sudo

# Best-effort systemctl handling (skip if not present).
USBMUXD_WAS_ACTIVE=0
USBMUXD_MANAGED=0

service_exists_systemd() {
  systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "usbmuxd.service"
}

stop_usbmuxd() {
  if command -v systemctl >/dev/null 2>&1 && service_exists_systemd; then
    USBMUXD_MANAGED=1
    if systemctl is-active --quiet usbmuxd; then
      USBMUXD_WAS_ACTIVE=1
      echo "[*] Stopping usbmuxd (systemd)..."
      sudo systemctl stop usbmuxd
    else
      echo "[*] usbmuxd is not active; not stopping."
    fi
  else
    echo "[*] systemctl/usbmuxd.service not found; skipping stop/start of usbmuxd."
  fi
}

start_usbmuxd_if_needed() {
  if (( USBMUXD_MANAGED == 1 )) && (( USBMUXD_WAS_ACTIVE == 1 )); then
    echo "[*] Starting usbmuxd (systemd)..."
    sudo systemctl start usbmuxd || true
  fi
}

cleanup() {
  # Always try to restore usbmuxd state if we stopped it.
  start_usbmuxd_if_needed

  # Remove the repo folder we cloned/updated so the script leaves no artifacts behind.
  # (We cd back to the starting directory first so we are not inside the folder we're deleting.)
  local repo_path
  if [[ "$REPO_DIR" = /* ]]; then
    repo_path="$REPO_DIR"
  else
    repo_path="${START_DIR}/${REPO_DIR}"
  fi

  if [[ -d "$repo_path" ]]; then
    cd "$START_DIR" 2>/dev/null || true
    echo "[*] Cleaning up: removing '${repo_path}'..."
    sudo rm -rf "$repo_path" 2>/dev/null || rm -rf "$repo_path" || true
  fi
}
trap cleanup EXIT

stop_usbmuxd

# Clone or update repo
if [[ -d "${REPO_DIR}/.git" ]]; then
  echo "[*] Repo exists; updating ${REPO_DIR}..."
  git -C "$REPO_DIR" pull --ff-only
elif [[ -e "$REPO_DIR" ]]; then
  echo "Error: '$REPO_DIR' exists but is not a git repo. Move it aside or delete it." >&2
  exit 1
else
  echo "[*] Cloning ${REPO_URL}..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

DOCKER_DIR="${REPO_DIR}/${DOCKER_SUBDIR}"
if [[ ! -d "$DOCKER_DIR" ]]; then
  echo "Error: expected docker directory not found at '$DOCKER_DIR'." >&2
  exit 1
fi

cd "$DOCKER_DIR"

echo "[*] Building docker container (sudo ./build.sh)..."
sudo ./build.sh

echo "[*] Running restore (sudo ./run.sh ${RUN_ARGS[*]})..."
sudo ./run.sh "${RUN_ARGS[@]}"

echo "[*] Done."
