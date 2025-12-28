*Before reading this beaware this was created by ChatGPT.


# idevicerestore Docker Restore Helper

A tiny wrapper script (`idevicerestore_docker_restore.sh`) that automates the **Docker-based** workflow from the official **libimobiledevice/idevicerestore** project: build the container, then run `idevicerestore` against a USB-connected iOS/iPadOS device.

> **⚠️ Data-loss warning:** `idevicerestore` can **irreversibly destroy user data**. Back up your device first and use at your own risk. citeturn1view0  
> This script defaults to `--erase --latest`, which performs a full restore and **erases all data**.

---

## What this script does

When you run:

```bash
./idevicerestore_docker_restore.sh [idevicerestore args...]
```

the script:

1. Ensures the `idevicerestore` repo exists locally (expected folder: `./idevicerestore`).
2. Changes into `idevicerestore/docker/`.
3. Runs the upstream Docker helper scripts:
   - `build.sh` to build an image (`idevicerestore-docker`)
   - `run.sh …` to start the container and run `idevicerestore`
   - `run.sh` runs the container with privileges and host networking, mounts `/dev` and udev control sockets, and calls `idevicerestore.sh`, which starts `usbmuxd` and then runs `idevicerestore "$@"`.

---

## Requirements

- Linux host with:
  - **bash**
  - **git**
  - **Docker** (and permission to run it)
  - **sudo** access (this script calls `sudo ./build.sh` and `sudo ./run.sh`)
- A USB connection to the iOS/iPadOS device (reliable cable/port recommended).

> Note: the upstream Docker workflow starts `usbmuxd` **inside the container** before launching `idevicerestore`.
> If you have trouble detecting devices, one community workaround is to stop/disable `usbmuxd` on the host because the container starts its own instance. 

---

## Quick start

```bash
chmod +x idevicerestore_docker_restore.sh
./idevicerestore_docker_restore.sh
```

With **no arguments**, the script uses:

```text
--erase --latest
```

- `--latest` downloads (on-demand) the **latest available firmware** and asks you to choose from **currently signed** versions unless you also pass `-y`.
- `--erase` performs a full restore (wipe).

---

## Usage examples

### Restore to latest signed firmware (keep user data when possible)

```bash
./idevicerestore_docker_restore.sh --latest
```

By default, `idevicerestore --latest` performs an update restore that preserves user data when possible.

### Factory reset (wipe + latest signed firmware)citeturn1view0turn3view0


```bash
./idevicerestore_docker_restore.sh --erase --latest
```

### Non-interactive (dangerous)

```bash
./idevicerestore_docker_restore.sh --erase --latest -y
```

`-y/--no-input` disables prompts and some safety checks; use with extra caution.

### Restore from a local IPSW file

```bash
./idevicerestore_docker_restore.sh /path/to/Firmware.ipsw
```

The `PATH` argument can be a `.ipsw` or an extracted IPSW directory.
(If you also use `--latest`, `PATH` is ignored.)

---

## Troubleshooting

### “Cannot connect to the Docker daemon”
- Make sure Docker is installed and running.
- Because this wrapper uses `sudo`, you’ll be prompted for your password unless you adjust the script.
- Alternative: add your user to the `docker` group and remove `sudo` from the script (advanced).

### Device not detected / USB issues
- Try a different cable/port.
- Ensure the container is allowed USB access (the upstream `run.sh` uses `--privileged` and mounts `/dev`).
- If you suspect a `usbmuxd` conflict, try stopping host `usbmuxd` (community suggestion).

### “iPhone locked to owner” after restore
A restore can complete successfully and still boot to “**iPhone Locked to Owner**” if Activation Lock is enabled on that device/account. (You’ll need the original Apple ID credentials to proceed.)

### “Device failed to enter restore mode”
This can happen mid-restore (often reported as “most likely image personalization failed”). Try another cable/port and ensure you’re restoring a currently signed IPSW.

---

## Script notes (important)

The version of `idevicerestore_docker_restore.sh` in this folder contains a literal `...` placeholder. In **bash**, that will be treated as a command and will fail.

If you see that line, delete it and ensure you have the expected repository/bootstrap lines (example):

```bash
if [[ ! -d "$REPO_DIR" ]]; then
  echo "[*] Cloning idevicerestore into ./$REPO_DIR ..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

DOCKER_DIR="${REPO_DIR}/${DOCKER_SUBDIR}"
```

---

## More options / documentation

- Run `idevicerestore --help` or consult the man page for the full option list. citeturn6view0
- Upstream project documentation (including Docker workflow notes).

---

## Credits

- Uses the upstream Docker workflow shipped with **libimobiledevice/idevicerestore**.
