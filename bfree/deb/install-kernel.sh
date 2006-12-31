#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
	[ -x /usr/bin/su-me ] && DISPLAY="" exec su-me "$0" "$@"

	echo Error: You must be root to run this script!
	exit 1
fi

source /root/install-packages
VER="$KVERS"
[ -z "$KVERS" ] && VER=2.6.18.6-slh-smp-1
SUB=1
ALSA=
X_CONF="/etc/X11/xorg.conf"

rm -f	/boot/System.map \
	/boot/vmlinuz \
	initrd.img

#grep -q '  */sbin/update-grub$' /etc/kernel-img.conf 2> /dev/null && sed -i 's%=.*sbin/update-grub%= update-grub%' /etc/kernel-img.conf 2> /dev/null

# install important dependencies
#[ -x /usr/bin/gcc-4.1 ]      || apt-get install gcc-4.1
#[ -x /usr/sbin/mkinitramfs ] || apt-get install initramfs-tools

# install kernel, headers and our patches to the vanilla tree
#dpkg -i linux-image-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
#dpkg -i linux-headers-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
#dpkg -i linux-doc-"$VER"_"$SUB"_all.deb
#test -n "$ALSA" && dpkg -i alsa-modules-"$VER"_"$ALSA"+"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
#test -f linux-custom-patches-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb && dpkg -i linux-custom-patches-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb

ln -fs "vmlinuz-$VER" /boot/vmlinuz
ln -fs "boot/vmlinuz-$VER" /vmlinuz

# we do need an initrd
#if [ ! -r "/boot/initrd.img-$VER" ]; then
#	mkinitramfs -o "/boot/initrd.img-$VER" "$VER"
#fi
#ln -fs "initrd.img-$VER"        /boot/initrd.img
#ln -fs "boot/initrd.img-$VER"   /initrd.img

ln -fs "System.map-$VER"        /boot/System.map

# in case we just created an initrd, update menu.lst
#update-grub

# set symlinks to the kernel headers
rm -f "/lib/modules/$VER/build" >/dev/null 2>&1
ln -s "/usr/src/linux-headers-$VER" "/lib/modules/$VER/build"
ln -fs "linux-headers-$VER" /usr/src/linux >/dev/null 2>&1

# remove agpgart, fglrx, radeon modules
perl -pi -e 's/^agpgart\n?//' /etc/modules
perl -pi -e 's/^fglrx\n?//' /etc/modules
perl -pi -e 's/^radeon\n?//' /etc/modules

# hints for fglrx
if grep -q '"fglrx"' "$X_CONF"; then
	echo "ATI RADEON 3D acceleraction will NOT work with the new kernel until"
	echo "the driver is reinstalled."
	echo
fi

# workaround for nvidia
if grep -q '"nvidia"' "$X_CONF"; then
	perl -pi -e 's/^([\s]*Driver\s*)"nvidia"/\1"nv"/g' "$X_CONF"
	grep -q ^nvidia /etc/modules || echo nvidia >> /etc/modules
	echo "NVIDIA driver has been DISABLED!"
	echo
fi

# alsa sound hack
rm -f /var/lib/alsa/asound.state
echo alsa sound will be muted next start.
echo use "alsactl store" as root to save it after checking the volumes.

