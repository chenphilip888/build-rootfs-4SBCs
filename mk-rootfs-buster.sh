#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ -e $TARGET_ROOTFS_DIR ]; then
	sudo rm -rf $TARGET_ROOTFS_DIR
fi

if [ "$ARCH" == "armhf" ]; then
	ARCH='armhf'
elif [ "$ARCH" == "arm64" ]; then
	ARCH='arm64'
else
    echo -e "\033[36m please input is: armhf or arm64...... \033[0m"
fi

if [ ! $VERSION ]; then
	VERSION="release"
fi

if [ ! -e binary-tar.tar.gz ]; then
	echo "\033[36m Run sudo lb build first \033[0m"
fi

finish() {
	sudo umount $TARGET_ROOTFS_DIR/dev
	exit -1
}
trap finish ERR

echo -e "\033[36m Extract image \033[0m"
sudo tar -xpf binary-tar.tar.gz

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf ../packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# overlay folder
sudo cp -rf ../overlay/* $TARGET_ROOTFS_DIR/

echo -e "\033[36m Change root.....................\033[0m"
if [ "$ARCH" == "armhf" ]; then
	sudo cp /usr/bin/qemu-arm-static $TARGET_ROOTFS_DIR/usr/bin/
elif [ "$ARCH" == "arm64"  ]; then
	sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/
fi
sudo mount -o bind /dev $TARGET_ROOTFS_DIR/dev

cat << EOF | sudo chroot $TARGET_ROOTFS_DIR

apt-get update
apt-get upgrade -y

chmod o+x /usr/lib/dbus-1.0/dbus-daemon-launch-helper
chmod +x /etc/rc.local

#---------------system--------------
apt-get install -y git fakeroot devscripts cmake binfmt-support dh-make dh-exec pkg-kde-tools device-tree-compiler \
bc cpio parted dosfstools mtools libssl-dev dpkg-dev ntp rsyslog wget gdb net-tools inetutils-ping openssh-server \
ifupdown alsa-utils python vim ntp git libssl-dev vsftpd tcpdump can-utils i2c-tools strace network-manager onboard \
evtest sox libsox-fmt-all
apt-get install -f -y

if [ "$BOARD" != "rpi4b" ]; then
dpkg -i /packages/xserver/*.deb
apt-get install -f -y
apt-get install -y libinput-bin libinput10 xserver-xorg-input-all xserver-xorg-input-libinput
fi

if [ "$BOARD" == "radxa" ]; then
#------------------rkwifibt------------
echo -e "\033[36m Install rkwifibt.................... \033[0m"
dpkg -i  /packages/rkwifibt/*.deb
apt-get install -f -y
ln -s /system/etc/firmware /vendor/etc/
elif [ "$BOARD" == "rpi4b" ]; then
#------------------rpiwifi-------------
echo -e "\033[36m Install rpiwifi..................... \033[0m"
dpkg -i /packages/rpiwifi/firmware-brcm80211_20190114-2_all.deb
cp /packages/rpiwifi/brcmfmac43455-sdio.txt /lib/firmware/brcm/
apt-get install -f -y
fi

#---------------Clean--------------
rm -rf /var/lib/apt/lists/*

EOF

sudo umount $TARGET_ROOTFS_DIR/dev
