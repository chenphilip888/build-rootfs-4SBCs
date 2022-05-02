#!/bin/bash -e

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

install_mali() {
    case $1 in
        rk3288)
            dpkg -i /packages/libmali/libmali-midgard-t76x-r14p0-r0p0-x11_1.9-1_armhf.deb
            dpkg -i /packages/libmali/libmali-midgard-t76x-r14p0-r0p0-x11-dbgsym_1.9-1_armhf.deb
            ;;
        rk3399|rk3399pro)
            dpkg -i /packages/libmali/libmali-midgard-t86x-r14p0-x11_*.deb
            ;;
        rk3328)
            dpkg -i /packages/libmali/libmali-utgard-450-r7p0-x11_1.9-1_arm64.deb
            dpkg -i /packages/libmali/libmali-utgard-450-r7p0-x11-dbgsym_1.9-1_arm64.deb
            ;;
        rk3326|px30)
            MALI=bifrost-g31
            ;;
        rk3128|rk3036)
            MALI=utgard-400
            ;;
        rk3568|rk3566)
            MALI=bifrost-g52-g2p0
            ;;
    esac

    # apt install -f /packages/libmali/libmali-*$MALI*-x11*.deb
}

init_rkwifibt() {
    case $1 in
        rk3288)
            rk_wifi_init /dev/ttyS0
            ;;
        rk3399|rk3399pro)
	    rk_wifi_init /dev/ttyS0
            ;;
        rk3328)
	    rk_wifi_init /dev/ttyS0
            ;;
        rk3326|px30)
	    rk_wifi_init /dev/ttyS1
            ;;
        rk3128|rk3036)
	    rk_wifi_init /dev/ttyS0
            ;;
        rk3566)
	    rk_wifi_init /dev/ttyS1
            ;;
        rk3568)
	    rk_wifi_init /dev/ttyS8
            ;;
    esac
}

function update_npu_fw() {
    /usr/bin/npu-image.sh
    sleep 1
    /usr/bin/npu_transfer_proxy&
}

COMPATIBLE=$(cat /proc/device-tree/compatible)
if [[ $COMPATIBLE =~ "rk3288" ]];
then
    CHIPNAME="rk3288"
elif [[ $COMPATIBLE =~ "rk3328" ]]; then
    CHIPNAME="rk3328"
elif [[ $COMPATIBLE =~ "rk3399" && $COMPATIBLE =~ "rk3399pro" ]]; then
    CHIPNAME="rk3399pro"
    update_npu_fw
elif [[ $COMPATIBLE =~ "rk3399" ]]; then
    CHIPNAME="rk3399"
elif [[ $COMPATIBLE =~ "rk3326" ]]; then
    CHIPNAME="rk3326"
elif [[ $COMPATIBLE =~ "px30" ]]; then
    CHIPNAME="px30"
elif [[ $COMPATIBLE =~ "rk3128" ]]; then
    CHIPNAME="rk3128"
elif [[ $COMPATIBLE =~ "rk3566" ]]; then
    CHIPNAME="rk3566"
elif [[ $COMPATIBLE =~ "rk3568" ]]; then
    CHIPNAME="rk3568"
else
    CHIPNAME="rk3036"
fi
COMPATIBLE=${COMPATIBLE#rockchip,}
BOARDNAME=${COMPATIBLE%%rockchip,*}

# first boot configure
if [ ! -e "/usr/local/first_boot_flag" ] ;
then
    echo "It's the first time booting."
    echo "The rootfs will be configured."

    # Force rootfs synced
    mount -o remount,sync /

    install_mali ${CHIPNAME}
    setcap CAP_SYS_ADMIN+ep /usr/bin/gst-launch-1.0

    # Cannot open pixbuf loader module file
    if [ -e "/usr/lib/arm-linux-gnueabihf" ] ;
    then
	/usr/lib/arm-linux-gnueabihf/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders > /usr/lib/arm-linux-gnueabihf/gdk-pixbuf-2.0/2.10.0/loaders.cache
	update-mime-database /usr/share/mime/
    elif [ -e "/usr/lib/aarch64-linux-gnu" ];
    then
	/usr/lib/aarch64-linux-gnu/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders > /usr/lib/aarch64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache
    fi

    rm -rf /packages

    # The base target does not come with lightdm
    systemctl restart lightdm.service || true

    touch /usr/local/first_boot_flag
fi

# init rkwifibt
init_rkwifibt ${CHIPNAME}
