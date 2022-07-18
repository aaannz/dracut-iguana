#!/bin/bash

NEWROOT=${NEWROOT:-/mnt}
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
mkdir -p /var/lib/dbus
rm -f /var/lib/dbus/machine-id
dbus-uuidgen --ensure
systemd-machine-id-setup

# make sure there are no pending changes in devices
udevadm settle -t 60

# from now on, disable automatic RAID assembly
udevproperty rd_NO_MD=1

# config podman

mkdir -p /etc/containers/
cat << 'EOF' > /etc/containers/containers.conf
# We are running in initramfs and cannot pivout out
[engine]
no_pivot_root = true
EOF

# what we need:
# - registry (hardcode registry.suse.com?, take from control file? opensuse will want registry.opensuse.org. Others would want different
# - image name
# - how to start the image:
#   - bind mounts, volumes, priviledged, ports published
# - directory with results

if [ -f control.yaml ]; then
   #TODO
   sleep 1
fi

# load containers as specified in command line
if [ -n "$CONTAINERS" ]; then
  Echo "Using container list from kcmdline: ${CONTAINERS}"
  readarray -d , -t container_array <<< "$CONTAINERS"

  podman volume exists results || \
    podman volume create --opt device=tmpfs --opt type=tmpfs --opt o=nodev,noexec results

  for c in "${container_array}"; do
    Echo "Before container run:\n$(free -m)"
    # pull image
    #TODO: remove tls-verify-false and instead pull correct CA
    podman image pull --tls-verify=false -- $c > /progress

    #TODO: image validation, cosign

    # run container
    #TODO: load result volume based on the info from control.yaml
    #TODO: concurrent run of multiple container - podman-compose?
    podman run \
    --privileged --rm --tty --interactive --network=host \
    --annotation="iguana=True" --env="iguana=True" \
    --env-host --mount=type=volume,source=results,destination=/iguana \
    -- $c

    echo "podman run \
    --privileged --rm --tty --interactive --network=host \
    --annotation=\"iguana=True\" --env=\"iguana=True\" \
    --env-host --mount=type=volume,source=results,destination=/iguana \
    -- $c" > run_container.sh

    Echo "After container run:\n$(free -m)"

    #TODO uncomment adfter debug
    #podman image rm -- $c
    Echo "After image:\nrm $(free -m)"
  done
fi

Echo "Containers run finished, iguana ends"
sleep 10

# persist generated machineid
if [ -n $MACHINE_ID]; then
  echo $MACHINE_ID > $NEWROOT/etc/machine-id
fi

# in case installed system has different kernel then the one in initrd
if [ -n "$kernelAction" ] ; then
  umount -a
  sync
  if [ "$kernelAction" = "reboot" ] ; then
    Echo "Reboot with correct kernel version in 10s"
    sleep 10
    reboot -f
  elif [ "$kernelAction" = "kexec" ] ; then
    kexec -e
    Echo "Kexec failed, reboot with correct kernel version in 10s"
    sleep 10
    reboot -f
  fi
fi

[ -n "$PROGRESS_PID" ] && kill $PROGRESS_PID
[ -n "$DC_PROGRESS_PID" ] && kill $DC_PROGRESS_PID
