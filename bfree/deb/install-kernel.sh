#!/bin/sh

if [ $(id -u) != 0 ]; then
	echo Error: You must be root to run this script!
	exit 1
fi

SUB=1
ALSA=

rm -f	/boot/System.map \
	/boot/vmlinuz \
	initrd.img

source /root/install-packages

VER="$KVERS"

dpkg -i linux-image-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
dpkg -i linux-headers-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
dpkg -i linux-doc-"$VER"_"$SUB"_all.deb

for mp in $KERNELMODULES; do
  ls -art $mp-$VER_*_$(dpkg-architecture -qDEB_BUILD_ARCH).deb | tail -n 1 | xargs dpkg -i || echo "ERROR: KERNEL MODULE $mp FAILED !!"
done

# in case we loaded any more modules
apt-get --yes -f install

test -n "$ALSA" && dpkg -i alsa-modules-"$VER"_"$ALSA"+"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb
test -f linux-custom-patches-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb && dpkg -i linux-custom-patches-"$VER"_"$SUB"_$(dpkg-architecture -qDEB_BUILD_ARCH).deb

#ln -sf System.map-$VER /boot/System.map
#ln -sf vmlinuz-$VER /boot/vmlinuz

# install important dependencies
dpkg -l module-init-tools &>/dev/null || apt-get -y install module-init-tools
update-rc.d module-init-tools start 20 S . >/dev/null

rm -rf /usr/src/linux /usr/src/linux-$VER /lib/modules/$VER/build
if [ ! -d /usr/src/linux-headers-$VER/scripts ]; then
	rm -f /usr/src/linux-headers-$VER/scripts
	ln -s ../linux-kbuild-2.6.18/scripts /usr/src/linux-headers-$VER
fi

ln -s linux-headers-$VER /usr/src/linux-$VER
ln -s /usr/src/linux-$VER /lib/modules/$VER/build  
cp -f /boot/config-$VER /usr/src/linux-$VER/.config
rm -rf /usr/src/linux-$VER/Documentation
ln -s /usr/share/doc/linux-doc-$VER/Documentation /usr/src/linux-$VER/Documentation
ln -sf boot/vmlinuz-$VER /vmlinuz

# hack for new installer
X_CONF=XF86Config-4
if which Xorg >/dev/null; then
	[ -e /etc/X11/xorg.conf ] && X_CONF=xorg.conf
fi

# psmouse fix
grep -q ^psmouse /etc/modules || echo psmouse >> /etc/modules

# fix modules
rm -f /etc/modules-*

# mouse fix
perl -pi -e 's|(\s*Option\s+"Protocol"\s+)"auto"|\1"IMPS/2|' "/etc/X11/$X_CONF"
[ -f "/etc/X11/$X_CONF.1st" ] && perl -pi -e 's|(\s*Option\s+"Protocol"\s+)"auto"|\1"IMPS/2"|' "/etc/X11/$X_CONF.1st"
echo 'Notice: the mouse protocol "auto" has been changed to "IMPS/2"!'
echo 'If you have problems change it to "PS/2" - "auto" does not work with 2.6.'
echo "Change was done in /etc/X11/$X_CONF (and /etc/X11/$X_CONF.1st)."
echo

# change usbdevfs to usbfs with lowered right setting
perl -pi -e "s|.*/proc/bus/usb.*|usbfs  /proc/bus/usb  usbfs  devmode=0666  0  0|" /etc/fstab
echo usbdevfs has been replaced by usbfs in /etc/fstab with devmode=0666

# camera group hack
#USER=$(grep 1000 /etc/passwd|cut -f1 -d:)
#GROUP=$(echo $(groups $USER|cut -f2 -d:)|sed "s/ /,/g")
#echo $GROUP|grep -q camera || (
#[ "$USER" ] &&  usermod -G $GROUP,camera $USER
#)
