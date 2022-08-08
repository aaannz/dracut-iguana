#!/bin/bash

[ -n "$IGUANA_DEBUG" ] && set -x

if [ -z "$root" ] || [ "$root"x != "iguanabootx" ]; then
  exit 0
fi

NEWROOT=${NEWROOT:-/sysroot}
export NEWROOT

# Open reporting fifo
if [ -e /usr/bin/plymouth ] ; then
    mkfifo /progress
    bash -c 'while true ; do read msg < /progress ; plymouth message --text="$msg" ; done ' &
    PROGRESS_PID=$!
else
    mkfifo /progress
    bash -c 'while true ; do read msg < /progress ; echo -n -e "\033[2K$msg\015" >/dev/console ; done ' &
    PROGRESS_PID=$!
fi

echo -n > /dc_progress
bash -c 'tail -f /dc_progress | while true ; do read msg ; echo "$msg" >/progress ; done ' &
DC_PROGRESS_PID=$!

if ! declare -f Echo > /dev/null ; then
  Echo() {
    echo -e "$@"
    echo -e "$@" > /progress
  }
fi

Echo "Preparing Iguana boot environment"

# Clear preexisting machine id if present
rm -f /etc/machine-id
rm -f /etc/hostname
rm -f /var/lib/dbus/machine-id
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure
systemd-machine-id-setup

# make sure there are no pending changes in devices
udevadm settle -t 60

# from now on, disable automatic RAID assembly
udevproperty rd_NO_MD=1

# config podman
mkdir -p /etc/containers/containers.conf.d
cat << 'EOF' > /etc/containers/containers.conf.d/no_pivot_root.conf
# We are running in initramfs and cannot pivout out
[engine]
no_pivot_root = true
EOF

# TODO: add local image stores for when using DVD/ISO.
# ensure we are using overlay driver, SLE was forcing btrfs
cat << 'EOF' >/etc/containers/storage.conf
[storage]
driver = "overlay"
runroot = "/var/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
additionalimagestores = []

size = ""
EOF

# what we need:
# - registry (hardcode registry.suse.com?, take from control file? opensuse will want registry.opensuse.org. Others would want different
# - image name
# - how to start the image:
#   - bind mounts, volumes, priviledged, ports published
# - directory with results

# Directories for container data sharing and results
mkdir -p /iguana
mkdir -p $NEWROOT

IGUANA_BUILDIN_CONTROL="/etc/iguana/control.yaml"
IGUANA_CMDLINE_EXTRA="--newroot=${NEWROOT} ${IGUANA_DEBUG:+--debug --log-level=debug}"

if [ -n $IGUANA_CONTROL_URL ]; then
  curl --insecure -o control_url.yaml -L -- "$IGUANA_CONTROL_URL"
  if [ $? -ne 0 ]; then
    Echo "Failed to download provided control file, ignoring"
  fi
fi

if [ -f control_url.yaml ]; then
  /usb/bin/iguana-workflow $IGUANA_CMDLINE_EXTRA control_url.yaml
elif [ -n "$IGUANA_CONTAINERS" ]; then
  Echo "Using container list from kcmdline: ${IGUANA_CONTAINERS}"
  readarray -d , -t container_array <<< "$IGUANA_CONTAINERS"

  # once iguana-workflow is stable, replace this by workflow writer and workflow run
  for c in "${container_array}"; do
    # pull image
    #TODO: remove tls-verify-false and instead pull correct CA
    podman image pull --tls-verify=false -- $c > /progress

    #TODO: image validation, cosign

    # run container
    #TODO: load result volume based on the info from control.yaml
    #TODO: concurrent run of multiple container - podman-compose?
    podman run \
    --privileged --rm --tty --interactive --network=host \
    --annotation=iguana=True --env=iguana=True --env=NEWROOT=${NEWROOT} \
    --volume="/dev:/dev" \
    --mount=type=bind,source=/iguana,target=/iguana \
    -- $c

    [ -z "$IGUANA_DEBUG" ] && podman image rm -- $c
  done
# control.yaml is buildin control file in initrd
elif [ -f "$IGUANA_BUILDIN_CONTROL" ]; then
  /usb/bin/iguana-workflow $IGUANA_CMDLINE_EXTRA "$IGUANA_BUILDIN_CONTROL"
fi

Echo "Containers run finished"

# Mount new roots for upcoming switch_root
if [ -f /iguana/newroot_device ]; then
  cat /iguana/newroot_device | while read device mountpoint; do
    mount "$device" "$mountpoint"
  done
fi

# TODO: add proper kernel action parsing
# TODO: this is really naive
# Scan $NEWROOT for installed kernel, initrd and command line
# in case installed system has different kernel then the one we are running we need to kexec to new one
if mount | grep -q ${NEWROOT}; then
  CUR_KERNEL=$(uname -r)
  NEW_KERNEL=$(ls ${NEWROOT}/lib/modules/)
  if [ "$CUR_KERNEL" != "$NEW_KERNEL" ]; then
    # different kernel detected - try kexec to new one
    kexec -l "${NEWROOT}/boot/vmlinuz" --initrd="${NEWROOT}/boot/initrd" --reuse-cmdline
    umount -a
    sync
    kexec -e
    Echo "Kexec failed, rebooting with correct kernel version in 10s"
    sleep 10
    reboot -f
  fi
else
  Echo "[WARN] New root not mounted!"
fi

[ -n "$PROGRESS_PID" ] && kill $PROGRESS_PID
[ -n "$DC_PROGRESS_PID" ] && kill $DC_PROGRESS_PID
