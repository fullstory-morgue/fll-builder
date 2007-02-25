#!/bin/bash

set -e

SELF="fll-build"

#################################################################
#		Synopsis					#
#################################################################
# fll-build(8): build script for a debian 'sid' live linux cd	#
# that uses code developed by members of the F.U.L.L.S.T.O.R.Y	#
# project to enhance hardware detection and linux experience.	#
#################################################################

print_copyright() {
	cat \
<<EOF

Copyright (C) 2006 - 2007 F.U.L.L.S.T.O.R.Y Project

F.U.L.L.S.T.O.R.Y Project Homepage:
http://developer.berlios.de/projects/fullstory

F.U.L.L.S.T.O.R.Y Subversion Archive:
svn://svn.berlios.de/fullstory/trunk
http://svn.berlios.de/svnroot/repos/fullstory
http://svn.berlios.de/viewcvs/fullstory (viewcvs)
http://svn.berlios.de/wsvn/fullstory (websvn)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this package; if not, write to the Free Software 
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, 
MA 02110-1301, USA.

On Debian GNU/Linux systems, the text of the GPL license can be
found in /usr/share/common-licenses/GPL.

EOF
}

print_help() {
	cat \
<<EOF

Usage: $SELF [options]

Options:
  -b|--buildarea		Path to temporary build area for live-cd chroot

  -c|--configfile		Path to alternate configfile
  				(default: /etc/fll-builder/fll-build.conf)

  -C|--copyright		Copyright information

  -d|--debug			Debug shell code execution (set -x)

  -h|--help			Information about using this program

  -k|--kernel			URL to kernel zip package

  -n|--chrootonly		Quit after preparing chroot

  -o|--output			ISO output dir

  -p|--preserve			Preserve build area when finished

  -P|--package-profile		Name of packages profile. Each profile is sourced from bash lists
  				(arrays) located at /etc/fll-builder/packages/<NAME>.bm.
  				(default: kde-lite or /etc/fll-builder/packages/kde-lite.bm)

  -s|--source			Retrieve all source packages for the release

  -S|--squashfs-sortfile 	Path to squashfs sort file

EOF
}

error() {
	echo -ne "$SELF error: "
	
	case $1 in
		1)
			echo "getopt failed"
			;;
		2)
			echo "invalid command line option"
			;;
		3)
			echo "unable to source alternate configfile"
			;;
		4)
			echo "unable to source packages profile module"
			;;
		5)	
			echo "buildarea not specified"
			;;
		6)
			echo "ISO output directory does not exist"
			;;
		*)
			echo "Unknown error code \"$1\"."
			set -- 255
			;;
	esac
	
	exit $1
}

#################################################################
#		root?						#
#################################################################
if (($UID)); then
	# allow user to access help or copyright info before su-me
	if [[ " $* " =~ ' (-h|--help) ' ]]; then
		print_help
		exit 0
	elif [[ " $* " =~ ' (-C|--copyright) ' ]]; then
		print_copyright
		exit 0
	fi
	# su-me, trap users UID
	DISPLAY= exec su-me "$0 --uid $UID" "$@"
fi

#################################################################
#		constant variable declarations			#
#################################################################
# host arch
DPKG_ARCH=$(dpkg --print-installation-architecture)

# Allow lazy development and testing
FLL_BUILD_BASE=$(dirname $0)
if [[ ! -f  $FLL_BUILD_BASE/debian/changelog ]]; then
	unset FLL_BUILD_BASE
fi

# fll defaults
FLL_BUILD_DEFAULTS="$FLL_BUILD_BASE/etc/default/distro"

# fll default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"

# package profile
FLL_BUILD_PACKAGE_PROFILE="kde-lite"
FLL_BUILD_PACKAGE_PROFDIR="$FLL_BUILD_BASE/etc/fll-builder/packages"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.d"
FLL_BUILD_TEMPLATES="$FLL_BUILD_SHARED/templates"
FLL_BUILD_EXCLUSION_LIST="$FLL_BUILD_SHARED/exclusion_list"

# apt sources in chroot
FLL_BUILD_DEBIANMIRROR="http://ftp.debian.org/debian/"
FLL_BUILD_DEBIANMIRROR_COMPONENTS="main"
FLL_BUILD_FLLMIRROR="http://sidux.com/debian/"
FLL_BUILD_FLLMIRROR_COMPONENTS="main fix.main"
FLL_HTTP_PROXY=""
FLL_FTP_PROXY=""

# cdebootstrap defaults
DEBOOTSTRAP_MIRROR="http://ftp.us.debian.org/debian"
DEBOOTSTRAP_FLAVOUR="minimal"
DEBOOTSTRAP_ARCH="$DPKG_ARCH"
DEBOOTSTRAP_DIST="sid"

# store current UID, override later if executed by !root
FLL_BUILD_OUTPUT_UID=$UID

#################################################################
#		source configfiles and functions		#
#################################################################
source "$FLL_BUILD_DEFAULTS"
source "$FLL_BUILD_CONFIG"

# source functions
for func in "$FLL_BUILD_FUNCTIONS"/*.bm; do
	source "$func"
done

#################################################################
#		parse command line				#
#################################################################
ARGS=$( getopt --name "$SELF" \
	--options b:c:CdD:hk:no:pP:sS: \
	--long buildarea,configfile,chrootonly,copyright,debdir,debug,help,kernel,output,package-profile,preserve,source,squashfs-sortfile:,uid: \
	-- $@ )

[[ $? == 0 ]] || error 1

eval set -- "$ARGS"

while true; do
	case $1 in
		-b|--buildarea)
			shift
			FLL_BUILD_AREA=$1
			;;
		-c|--configfile)
			shift
			FLL_BUILD_ALT_CONFIG=$1
			;;
		-C|--copyright)
			print_copyright
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			set -x
			;;
		-D|--debdir)
			# this need not be a documented feature
			# avoid encouraging its use by the public
			shift
			FLL_BUILD_LOCAL_DEBS=$1
			;;
		-h|--help)
			print_help
			exit 0
			;;
		-k|--kernel)
			shift
			FLL_BUILD_LINUX_KERNEL=$1
			;;
		-n|--chrootonly)
			FLL_BUILD_CHROOT_ONLY=1
			;;			
		-o|--output)
			shift
			FLL_BUILD_ISO_OUTPUT=$1
			;;
		-p|--preserve)
			FLL_BUILD_PRESERVE_CHROOT=1
			;;
		-P|--package-profile)
			shift
			FLL_BUILD_PACKAGE_PROFILE=$1
			;;
		-s|--source)
			FLL_BUILD_SOURCE_REL=1
			;;
		-S|--squashfs-sortfile)
			shift
			FLL_BUILD_SQUASHFS_SORTFILE=$1
			;;
		--uid)
			# this need not be a documented feature
			shift
			FLL_BUILD_OUTPUT_UID=$1
			;;
		--)
			shift
			break
			;;
		*)
			error 2
			;;
	esac
	shift
done

#################################################################
#		source local config				#
#################################################################
# alternate configfile
if [[ $FLL_BUILD_ALT_CONFIG ]]; then
	if [[ -s $FLL_BUILD_ALT_CONFIG ]]; then
		source "$FLL_BUILD_ALT_CONFIG"
	else
		error 3
	fi
fi

#################################################################
#		process package array(s)			#
#################################################################
if [[ -s "$FLL_BUILD_PACKAGE_PROFDIR"/"$FLL_BUILD_PACKAGE_PROFILE".bm ]]; then
	source "$FLL_BUILD_PACKAGE_PROFDIR"/"$FLL_BUILD_PACKAGE_PROFILE".bm
else
	error 4
fi

if [[ $FLL_PACKAGE_DEPMODS ]]; then
	for pkgmod in ${FLL_PACKAGE_DEPMODS[@]}; do
		echo "Processing: $FLL_BUILD_PACKAGE_PROFDIR/packages.d/${pkgmod}.bm"
		source "$FLL_BUILD_PACKAGE_PROFDIR"/packages.d/${pkgmod}.bm
	done
fi

# unconditionally evaluate i18n requirements
echo "Processing: $FLL_BUILD_PACKAGE_PROFDIR/packages.d/i18n.bm"
source "$FLL_BUILD_PACKAGE_PROFDIR"/packages.d/i18n.bm

echo
echo "########## PACKAGES TO BE INSTALLED ##########"
echo
echo ${FLL_PACKAGES[@]}
echo

#################################################################
#		preparations and sanity checks			#
#################################################################
# temporary staging areas within buildarea
if [[ $FLL_BUILD_AREA ]]; then
	mkdir -p "$FLL_BUILD_AREA"
	if [[ $FLL_BUILD_OUTPUT_UID != 0 ]]; then
		chown "$FLL_BUILD_OUTPUT_UID":"$FLL_BUILD_OUTPUT_UID" "$FLL_BUILD_AREA"
	fi
	# keep base directory "safe", create a hive of temporary dirs that get nuked on exit
	FLL_BUILD_TEMP=$(mktemp -p $FLL_BUILD_AREA -d $SELF.TEMP.XXXXX)
	FLL_BUILD_CHROOT=$(mktemp -p $FLL_BUILD_TEMP -d $SELF.CHROOT.XXXXX)
	FLL_BUILD_RESULT=$(mktemp -p $FLL_BUILD_TEMP -d $SELF.RESULT.XXXXX)
	mkdir -vp "${FLL_BUILD_RESULT}${FLL_MOUNTPOINT}" "$FLL_BUILD_RESULT"/boot
	if [[ $FLL_BUILD_SOURCE_REL ]]; then
		FLL_BUILD_SOURCE=$(mktemp -p $FLL_BUILD_TEMP -d $SELF.SOURCE.XXXXX)
		mkdir -vp "$FLL_BUILD_SOURCE"/{source,kernel}
	fi
else
	# must provide --buildarea or FLL_BUILD_AREA
	# there is no sane default
	error 5
fi

# distro name, lower casified
FLL_DISTRO_NAME_LC="$(tr A-Z a-z <<< $FLL_DISTRO_NAME)"
# distro name, upper casified
FLL_DISTRO_NAME_UC="$(tr a-z A-Z <<< $FLL_DISTRO_NAME)"

# check for $FLL_DISTRO_CODENAME
if [[ -z $FLL_DISTRO_CODENAME ]]; then
	FLL_DISTRO_CODENAME="snapshot"
fi

# set $FLL_DISTRO_CODENAME_SAFE, if undefined
if [[ -z $FLL_DISTRO_CODENAME_SAFE ]]; then
	FLL_DISTRO_CODENAME_SAFE="$(sed s/\ /_/g <<< $FLL_DISTRO_CODENAME)"
fi

# default iso output
if [[ -z $FLL_BUILD_ISO_OUTPUT ]]; then
	FLL_BUILD_ISO_OUTPUT="$FLL_BUILD_AREA"
fi

if [[ ! -d $FLL_BUILD_ISO_OUTPUT ]]; then
	error 6
fi

# live-package does this
LANG=C
LC_ALL=C
export LANG LC_ALL

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		main						#
#################################################################
#################################################################
#		bootstrap					#
#################################################################
cdebootstrap --arch="$DEBOOTSTRAP_ARCH" --flavour="$DEBOOTSTRAP_FLAVOUR" \
	"$DEBOOTSTRAP_DIST" "$FLL_BUILD_CHROOT" "$DEBOOTSTRAP_MIRROR"

#################################################################
#		patch and prepare chroot			#
#################################################################
cat_file_to_chroot chroot_policy	/usr/sbin/policy-rc.d
cat_file_to_chroot debian_chroot	/etc/debian_chroot
cat_file_to_chroot fstab		/etc/fstab
cat_file_to_chroot interfaces		/etc/network/interfaces
cat_file_to_chroot apt_sources_tmp	/etc/apt/sources.list
cat_file_to_chroot apt_conf		/etc/apt/apt.conf

copy_to_chroot /etc/hosts
copy_to_chroot /etc/resolv.conf

chroot_virtfs mount

# XXX: distro-defaults live environment detection
mkdir -vp "${FLL_BUILD_CHROOT}${FLL_MOUNTPOINT}"

#################################################################
#		prepare apt					#
#################################################################
# XXX: temporary workaround for keyring transition
chroot_exec apt-key update
chroot_exec apt-get update

# install gpg keyring for fll mirror
chroot_exec apt-get --allow-unauthenticated --assume-yes install "$FLL_DISTRO_NAME"-keyrings

# fetch & install gpg key for extra mirror
if [[ $FLL_BUILD_EXTRAMIRROR_GPGKEYID ]]; then
	# XXX: proxy => --keyserver-options http-proxy
	chroot_exec gpg --keyserver wwwkeys.eu.pgp.net --recv-keys "$FLL_BUILD_EXTRAMIRROR_GPGKEYID"
	chroot_exec apt-key add /root/.gnupg/pubring.gpg
fi

chroot_exec apt-get update

# store time stamp of package installation
PACKAGE_TIMESTAMP="$(date -u +%Y%m%d%H%M)"

#################################################################
#		debconf preseeding				#
#################################################################
chroot_exec apt-get --assume-yes install debconf

echo "locales	locales/default_environment_locale	select	en_US.UTF-8" | chroot_exec debconf-set-selections
echo "locales	locales/locales_to_be_generated	multiselect	be_BY.UTF-8 UTF-8, bg_BG.UTF-8 UTF-8, cs_CZ.UTF-8 UTF-8, da_DK.UTF-8 UTF-8, de_CH.UTF-8 UTF-8, de_DE.UTF-8 UTF-8, el_GR.UTF-8 UTF-8, en_AU.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, en_IE.UTF-8 UTF-8, en_US.UTF-8 UTF-8, es_ES.UTF-8 UTF-8, fi_FI.UTF-8 UTF-8, fr_FR.UTF-8 UTF-8, ga_IE.UTF-8 UTF-8, he_IL.UTF-8 UTF-8, hr_HR.UTF-8 UTF-8, hu_HU.UTF-8 UTF-8, it_IT.UTF-8 UTF-8, ja_JP.UTF-8 UTF-8, ko_KR.UTF-8 UTF-8, nl_NL.UTF-8 UTF-8, pl_PL.UTF-8 UTF-8, pt_BR.UTF-8 UTF-8, pt_PT.UTF-8 UTF-8, ru_RU.UTF-8 UTF-8, sk_SK.UTF-8 UTF-8, sl_SI.UTF-8 UTF-8, tr_TR.UTF-8 UTF-8, zh_CN.UTF-8 UTF-8, zh_TW.UTF-8 UTF-8" | chroot_exec debconf-set-selections

chroot_exec apt-get --assume-yes install locales

#################################################################
#		install kernel and extra modules		#
#################################################################
# install kernel early, avoid other packages from inserting their
# hooks into our live initramfs
if [[ $FLL_BUILD_INITRAMFS ]]; then
	# XXX: not yet in repo
	if ! install_local_debs "$FLL_BUILD_INITRAMFS"; then
		chroot_exec apt-get --assume-yes install fll-live-initramfs
	fi
	cat_file_to_chroot kernelimg-initramfs /etc/kernel-img.conf
else
	chroot_exec apt-get --assume-yes install busybox-sidux live-initrd-sidux
	# ask kernel postinst to call our desired hook -> mklive-initrd
	cat_file_to_chroot kernelimg /etc/kernel-img.conf
fi

# module-init-tools is required for installation of kernel and
# kernel-module binaries -> depmod
chroot_exec apt-get --assume-yes install module-init-tools

install_linux_kernel "$FLL_BUILD_LINUX_KERNEL"

# take these before package selection indirectly bloats the generated initramfs
cp -vL "$FLL_BUILD_CHROOT"/boot/miniroot.gz "$FLL_BUILD_RESULT"/boot/miniroot.gz
cp -vL "$FLL_BUILD_CHROOT"/boot/vmlinuz "$FLL_BUILD_RESULT"/boot/vmlinuz

#################################################################
#		install packages				#
#################################################################
# ensure distro-defaults is present before mass package installation
chroot_exec apt-get --assume-yes install distro-defaults 

# mass package installation
chroot_exec apt-get --assume-yes install ${FLL_PACKAGES[@]}

# XXX: this hack is FOR TESTING PURPOSES ONLY
if [[ -d $FLL_BUILD_LOCAL_DEBS ]]; then
	install_local_debs "$FLL_BUILD_LOCAL_DEBS"
fi

# XXX: put preseed scriptlets in a hook directory somewhere, with
# a defined api
#################################################################
#		add live user					#
#################################################################
chroot_exec adduser --no-create-home --disabled-password \
	--gecos "$FLL_LIVE_USER" "$FLL_LIVE_USER"

# add to groups, check if group exists first
for group in $FLL_LIVE_USER_GROUPS; do
	if chroot_exec getent group "$group"; then
		chroot_exec adduser "$FLL_LIVE_USER" "$group"
	fi
done

#################################################################
#		preseed chroot					#
#################################################################
# XXX: move user creation into early userspace -> flexibility
# lock down root and live user
sed -i "s#^\(root\|$FLL_LIVE_USER\):.*:\(.*:.*:.*:.*:.*:.*:.*\)#\1:\*:\2#" \
	"$FLL_BUILD_CHROOT"/etc/shadow

# hack inittab: init 5 by default, "immutable" bash login shells
sed -i -e 's#^id:[0-6]:initdefault:#id:5:initdefault:#' \
	-e 's#^\(~~:S:wait:\).\+#\1/bin/bash\ -login\ >/dev/tty1\ 2>\&1\ </dev/tty1#' \
	-e 's#^\(1\):\([0-9]\+\):\(respawn\):.\+#\1:\2:\3:/bin/bash\ -login\ >/dev/tty\1\ 2>\&1\ </dev/tty\1#' \
	-e 's#^\([2-6]\):\([0-9]\+\):\(respawn\):.\+#\1:\245:\3:/bin/bash\ -login\ >/dev/tty\1\ 2>\&1\ </dev/tty\1#' \
	"$FLL_BUILD_CHROOT"/etc/inittab

# run fix-fonts
if exists_in_chroot /usr/sbin/fix-fonts; then
	chroot_exec fix-fonts
fi

# set x-www-browser, use the popular firefox/iceweasel if present
# XXX: move into sidux-browser postinst
if exists_in_chroot /usr/bin/iceweasel; then
	chroot_exec update-alternatives --set x-www-browser /usr/bin/iceweasel
elif exists_in_chroot /usr/bin/konqueror; then
	chroot_exec update-alternatives --set x-www-browser /usr/bin/konqueror
fi

# use most as PAGER
if exists_in_chroot /usr/bin/most; then
	chroot_exec update-alternatives --set pager /usr/bin/most
fi

#################################################################
#		prepare result staging directory		#
#################################################################
# add templates (grub menu.lst/documentation/manual/autorun etc.)
for dir in "$FLL_BUILD_TEMPLATES"/common "$FLL_BUILD_TEMPLATES"/"$FLL_DISTRO_NAME"; do
	[[ -d $dir ]] || continue
	pushd $dir >/dev/null
		find . -not -path '*.svn*' -printf '%P\n' | \
			cpio -admpv --no-preserve-owner "$FLL_BUILD_RESULT"
	popd >/dev/null
done

# populate /boot/grub
cp -v "$FLL_BUILD_CHROOT"/usr/lib/grub/*-pc/{iso9660_stage1_5,stage2_eltorito,stage2} \
	"$FLL_BUILD_RESULT"/boot/grub/
cp -v "$FLL_BUILD_CHROOT"/boot/message.live "$FLL_BUILD_RESULT"/boot/message

if exists_in_chroot /boot/memtest86+.bin; then
	cp -v "$FLL_BUILD_CHROOT"/boot/memtest86+.bin "$FLL_BUILD_RESULT"/boot/memtest86+.bin
	echo					>> "$FLL_BUILD_RESULT"/boot/grub/menu.lst
	echo "title memtest86+"			>> "$FLL_BUILD_RESULT"/boot/grub/menu.lst
	echo "kernel /boot/memtest86+.bin"	>> "$FLL_BUILD_RESULT"/boot/grub/menu.lst
fi

# md5sums
pushd "$FLL_BUILD_RESULT" >/dev/null
	( find . -type f -not \( -name '*md5sums' -o -name '*.cat' \) -printf '%P\n' | \
		sort | xargs md5sum -b ) > "$FLL_IMAGE_DIR"/md5sums
popd >/dev/null

#################################################################
#		get sources					#
#################################################################
[[ $FLL_BUILD_SOURCE_REL ]] && fetch_source_code
# XXX: TODO: add a --print-uris option, so we can create
#            the source image on remote non-debian 
#            servers.

#################################################################
#		unpatch chroot					#
#################################################################

# umount proc
chroot_virtfs umount

# purge unwanted packages
chroot_exec dpkg --purge cdebootstrap-helper-diverts

# remove used hacks and patches
remove_from_chroot /etc/kernel-img.conf
remove_from_chroot /usr/sbin/policy-rc.d
remove_from_chroot /etc/debian_chroot
remove_from_chroot /etc/hosts
remove_from_chroot /etc/resolv.conf
remove_from_chroot /etc/apt/apt.conf

# remove live-cd mode identifier
rmdir -v "${FLL_BUILD_CHROOT}${FLL_MOUNTPOINT}"

# create final config files
cat_file_to_chroot hosts	/etc/hosts
cat_file_to_chroot hostname	/etc/hostname
cat_file_to_chroot apt_sources	/etc/apt/sources.list
cat_file_to_chroot sudoers	/etc/sudoers

# vimrc.local
if exists_in_chroot /etc/vim; then
	cat_file_to_chroot vimrc_local /etc/vim/vimrc.local
fi

# add version marker, this is the exact time stamp for our package list
echo -n "$FLL_DISTRO_NAME $FLL_DISTRO_VERSION" \
	> "$FLL_BUILD_CHROOT/etc/${FLL_DISTRO_NAME_LC}-version"
echo " - $FLL_DISTRO_CODENAME ($PACKAGE_TIMESTAMP)" \
	>> "$FLL_BUILD_CHROOT/etc/${FLL_DISTRO_NAME_LC}-version"

# a few dæmons are broken if log files are missing, 
# therefore nuke log and spool files while preserving permissions
find	"${FLL_BUILD_CHROOT}/var/cache/" \
	"${FLL_BUILD_CHROOT}/var/log/" \
		   -name \*\\.gz \
		-o -name \*\\.bz2 \
		-o -name \*\\.[0-9][0-9]? \
			-exec rm -f {} \;

find	"${FLL_BUILD_CHROOT}/var/log/" \
	"${FLL_BUILD_CHROOT}/var/mail/" \
	"${FLL_BUILD_CHROOT}/var/spool/" \
		-type f \
		-size +0 \
			-exec cp /dev/null '{}' \;

#################################################################
#		quit now?					#
#################################################################
[[ $FLL_BUILD_CHROOT_ONLY ]] && exit 0

#################################################################
#		compress fs					#
#################################################################
make_compressed_image

#################################################################
#		create iso					#
#################################################################
make_fll_iso

[[ $FLL_BUILD_SOURCE_REL ]] && make_fll_source_iso
# XXX: TODO. add an option to keep the unpacked sources tree for 
#            further processing (perhaps also omitting the ISO
#            creation.

exit 0

