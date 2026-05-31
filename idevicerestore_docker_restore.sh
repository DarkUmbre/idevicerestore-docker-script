#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/libimobiledevice/idevicerestore.git"
REPO_DIR="idevicerestore"
DOCKER_SUBDIR="docker"

START_DIR="$(pwd)"

# Default restore args.
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
need_cmd docker

USBMUXD_WAS_ACTIVE=0
USBMUXD_MANAGED=0

stop_usbmuxd() {
  if command -v systemctl >/dev/null 2>&1; then
    USBMUXD_MANAGED=1
    # We must check and stop BOTH the service and the socket. 
    # Otherwise, udev will restart usbmuxd on the host mid-restore when the device reboots.
    if systemctl is-active --quiet usbmuxd.service 2>/dev/null || systemctl is-active --quiet usbmuxd.socket 2>/dev/null; then
      USBMUXD_WAS_ACTIVE=1
      echo "[*] Stopping usbmuxd (systemd service & socket)..."
      sudo systemctl stop usbmuxd.socket usbmuxd.service 2>/dev/null || true
    else
      echo "[*] usbmuxd is not active; not stopping."
    fi
  else
    echo "[*] systemctl not found; skipping stop/start of usbmuxd."
  fi
}

start_usbmuxd_if_needed() {
  if (( USBMUXD_MANAGED == 1 )) && (( USBMUXD_WAS_ACTIVE == 1 )); then
    echo "[*] Starting usbmuxd (systemd)..."
    sudo systemctl start usbmuxd.socket usbmuxd.service 2>/dev/null || true
  fi
}

cleanup() {
  # Always try to restore usbmuxd state if we stopped it.
  start_usbmuxd_if_needed
  
  # Deliberately removed the 'rm -rf $REPO_DIR' logic from the original script.
  # Deleting it wiped downloaded IPSW caches and forced full docker rebuilds every run.
  echo "[*] Cleanup complete. Left '${REPO_DIR}' intact to preserve firmware cache."
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

# Fix for local IPSW files
declare -a PROCESSED_ARGS=()
for arg in "${RUN_ARGS[@]}"; do
  if [[ -f "$arg" && "$arg" == *.ipsw ]]; then
    filename=$(basename "$arg")
    echo "[*] Local IPSW detected. Copying '$arg' to '$DOCKER_DIR' for Docker context..."
    cp "$arg" "${DOCKER_DIR}/${filename}"
    PROCESSED_ARGS+=("$filename")
  else
    PROCESSED_ARGS+=("$arg")
  fi
done

cd "$DOCKER_DIR"

echo "[*] Building docker container (sudo ./build.sh)..."
sudo ./build.sh

echo "[*] Running restore (sudo ./run.sh ${PROCESSED_ARGS[*]})..."
sudo ./run.sh "${PROCESSED_ARGS[@]}"

echo "[*] Done."