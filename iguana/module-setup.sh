#!/bin/bash

# called by dracut
check() {
    return 0
}

# called by dracut
depends() {
    echo network dm
    return 0
}

# called by dracut
installkernel() {
    # for raid and crypt support, the kernel module is needed unconditionally, even in hostonly mode
    hostonly='' instmods raid1 dm_crypt =crypto
}


# called by dracut
install() {
    inst_multiple -o grep dig ldconfig date dbus-uuidgen systemd-machine-id-setup dmidecode seq \
                     lsblk dcounter curl head sync busybox tail podman

    inst_hook cmdline 91 "$moddir/iguana-root.sh"
    inst_hook pre-mount 99 "$moddir/iguana.sh"
    inst_hook initqueue/timeout 99 "$moddir/iguana-timeout.sh"

    echo "rd.neednet=1 rd.auto" > "${initdir}/etc/cmdline.d/50iguana.conf"

    # wicked duid generation rules - use ll instead of default llt. ll does not include time, just mac address and generic prefix
    mkdir -p "${initdir}/etc/wicked"
    echo "<config><addrconf><dhcp6><default-duid><ll/></default-duid></dhcp6></addrconf></config>" > "${initdir}/etc/wicked/client.xml"
}

