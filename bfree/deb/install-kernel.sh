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

update-rc.d module-init-tools start 20 S . >/dev/null

rm -rf /usr/src/linux /usr/src/linux-$KVERS /lib/modules/$KVERS/build
if [ ! -d /usr/src/linux-headers-$KVERS/scripts ]; then
	rm -f /usr/src/linux-headers-$KVERS/scripts
	ln -s ../linux-kbuild-2.6.18/scripts /usr/src/linux-headers-$KVERS
fi

ln -s linux-headers-$KVERS /usr/src/linux-$KVERS
ln -s /usr/src/linux-$KVERS /lib/modules/$KVERS/build  
cp -f /boot/config-$KVERS /usr/src/linux-$KVERS/.config
rm -rf /usr/src/linux-$KVERS/Documentation
ln -s /usr/share/doc/linux-doc-$KVERS/Documentation /usr/src/linux-$KVERS/Documentation
ln -sf boot/vmlinuz-$KVERS /vmlinuz

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

