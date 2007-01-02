#!/bin/bash

#################################################################
#		Synopsis					#
#################################################################
# fll-build(8): build script for a debian 'sid' live linux cd
# that uses code developed by members of the F.U.L.L.S.T.O.R.Y
# project to enhance hardware detection and linux experience.
#
# F.U.L.L.S.T.O.R.Y Project Homepage:
# http://developer.berlios.de/projects/fullstory
#
# F.U.L.L.S.T.O.R.Y Subversion Archive:
# svn://svn.berlios.de/fullstory/trunk
# http://svn.berlios.de/svnroot/repos/fullstory
# http://svn.berlios.de/viewcvs/fullstory (viewcvs)
# http://svn.berlios.de/wsvn/fullstory (websvn)

print_copyright() {
	cat \
<<EOF

Copyright (C) 2006 Sidux Crew, http://www.sidux.com
	Stefan Lippers-Hollmann <s.l-h@gmx.de>
	Niall Walsh <niallwalsh@users.berlios.de>
	Kel Modderman <kel@otaku42.de>

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
  -b|--buildarea	Path to temporary build area for live-cd chroot

  -c|--configfile	Path to alternate configfile
  (default: /etc/fll-builder/fll-build.conf)

  -C|--copyright	Copyright information

  -d|--debug		Debug shell code execution (set -x)

  -h|--help		Information about using this program

  -k|--kernel		URL to kernel zip package

  -n|--chrootonly	Quit after preparing chroot

  -o|--output		Path to final ISO output

  -p|--preserve		Preserve build area when finished

  -P|--packages		Path to alternative packages file

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
			echo "unable to source alternate packages file"
			;;
		5)	
			echo "buildarea not specified"
			;;
		6)
			echo "must specify a linux kernel"
			;;
		*)
			echo "Unknown error code \"$1\"."
			set -- 255
			;;
	esac
	
	return $1
}

#################################################################
#		root?						#
#################################################################
if (($UID)); then
	DISPLAY= exec su-me "$0 --uid $UID" "$@"
fi

#################################################################
#		constant variable declarations			#
#################################################################
# script name and version info
SELF="fll-build"

# host arch
DPKG_ARCH=$(dpkg --print-installation-architecture)

# Allow lazy development and testing
[[ -s ./debian/changelog ]] && FLL_BUILD_BASE="."

# fll defaults
if [[ -r $FLL_BUILD_BASE/etc/fll-build/distro ]]; then
	FLL_BUILD_DEFAULTS="$FLL_BUILD_BASE/etc/fll-build/distro"
else
	FLL_BUILD_DEFAULTS="$FLL_BUILD_BASE/etc/default/distro"
fi

# fll default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"
FLL_BUILD_PACKAGELIST="$FLL_BUILD_BASE/etc/fll-builder/packages.conf"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.bm"
FLL_BUILD_TEMPLATES="$FLL_BUILD_SHARED/templates"

#################################################################
#		source configfiles and functions.sh		#
#################################################################
source "$FLL_BUILD_DEFAULTS"
source "$FLL_BUILD_CONFIG"
source "$FLL_BUILD_FUNCTIONS"
source "$FLL_BUILD_PACKAGELIST"

#################################################################
#		more constant variable declarations		#
#################################################################
# apt sources in chroot
FLL_BUILD_DEBIANMIRROR="http://ftp.debian.org/debian/"
FLL_BUILD_FLLMIRROR="http://sidux.com/debian/"
FLL_HTTP_PROXY=""
FLL_FTP_PROXY=""

# cdebootstrap defaults
DEBOOTSTRAP_MIRROR="http://ftp.us.debian.org/debian"
DEBOOTSTRAP_FLAVOUR="minimal"
DEBOOTSTRAP_ARCH="$DPKG_ARCH"
DEBOOTSTRAP_DIST="sid"

#################################################################
#		parse command line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--options b:c:Cdhk:no:pP: \
		--long buildarea,configfile,chrootonly,copyright,debug,help,kernel,output,packages,preserve,uid: \
		-- $@
)

[[ $? -eq 0 ]] || error 1

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
			set -x
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
		-P|--packages)
			shift
			FLL_BUILD_ALT_PACKAGELIST=$1
			;;
		--uid)
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
#		process command line options			#
#		volatile variable declarations			#
#################################################################
# alternate configfile
if [[ $FLL_BUILD_ALT_CONFIG ]]; then
	if [[ -s $FLL_BUILD_ALT_CONFIG ]]; then
		source "$FLL_BUILD_ALT_CONFIG"
	else
		error 3
	fi
fi

# alternative package file
if [[ $FLL_BUILD_ALT_PACKAGELIST ]]; then
	if [[ -s $FLL_BUILD_ALT_PACKAGELIST ]]; then
		source "$FLL_BUILD_ALT_PACKAGELIST"
	else
		error 4
	fi
fi

# temporary staging areas within buildarea
if [[ $FLL_BUILD_AREA ]]; then
	mkdir -p "$FLL_BUILD_AREA" || error 4
	FLL_BUILD_CHROOT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
	FLL_BUILD_RESULT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
else
	# must provide --buildarea or FLL_BUILD_AREA
	# there is no sane default
	error 5
fi

# check kernel is provided
if [[ -z $FLL_BUILD_LINUX_KERNEL ]]; then
	error 6
fi

# distro name, lower casified
FLL_DISTRO_NAME_LC=$(tr A-Z a-z <<< $FLL_DISTRO_NAME)
# distro name, upper casified
FLL_DISTRO_NAME_UC=$(tr A-Z a-z <<< $FLL_DISTRO_NAME)

# check for $FLL_DISTRO_CODENAME
if [[ -z $FLL_DISTRO_CODENAME ]]; then
	FLL_DISTRO_CODENAME="snapshot"
fi

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		main						#
#################################################################
set -e

#################################################################
#		bootstrap					#
#################################################################
cdebootstrap --arch="$DEBOOTSTRAP_ARCH" --flavour="$DEBOOTSTRAP_FLAVOUR" \
	"$DEBOOTSTRAP_DIST" "$FLL_BUILD_CHROOT" "$DEBOOTSTRAP_MIRROR"

#################################################################
#		patch and prepare chroot			#
#################################################################
cat_file chroot_policy		/usr/sbin/policy-rc.d
cat_file debian_chroot		/etc/debian_chroot
cat_file fstab			/etc/fstab
cat_file interfaces		/etc/network/interfaces
cat_file apt_sources_tmp	/etc/apt/sources.list
cat_file apt_conf		/etc/apt/apt.conf

copy_to_chroot /etc/hosts
copy_to_chroot /etc/resolv.conf

virtfs mount

# XXX: distro-defaults live environment detection
mkdir -vp "${FLL_BUILD_CHROOT}${FLL_MOUNTPOINT}"

#################################################################
#		prepare apt					#
#################################################################
chroot_exec apt-get update
chroot_exec apt-get --allow-unauthenticated --assume-yes install "$FLL_DISTRO_NAME"-keyrings
chroot_exec apt-get update
PACKAGE_TIMESTAMP="$(date -u +%Y%m%d%H%M)"

#################################################################
#		debconf preseeding				#
#################################################################
chroot_exec apt-get --assume-yes install distro-defaults debconf

echo "locales	locales/default_environment_locale	select	en_US.UTF-8" | chroot_exec debconf-set-selections
echo "locales	locales/locales_to_be_generated	multiselect	de_AT.UTF-8 UTF-8, de_CH.UTF-8 UTF-8, de_DE.UTF-8 UTF-8, el_GR.UTF-8 UTF-8, en_AU.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, en_IE.UTF-8 UTF-8, en_US.UTF-8 UTF-8, es_ES.UTF-8 UTF-8, fr_FR.UTF-8 UTF-8, he_IL.UTF-8 UTF-8, ja_JP.UTF-8 UTF-8, nl_NL.UTF-8 UTF-8, pt_BR.UTF-8 UTF-8, pt_PT.UTF-8 UTF-8, ru_RU.UTF-8 UTF-8, tr_TR.UTF-8 UTF-8, zh_CN.UTF-8 UTF-8" | chroot_exec debconf-set-selections

#################################################################
#		install packages				#
#################################################################
chroot_exec apt-get --assume-yes install ${FLL_PACKAGES[@]}

#################################################################
#		add live user					#
#################################################################
chroot_exec adduser --no-create-home --disabled-password \
	--gecos "$FLL_LIVE_USER" "$FLL_LIVE_USER"

for group in $FLL_LIVE_USER_GROUPS; do
	if chroot_exec getent group "$group"; then
		chroot_exec adduser "$FLL_LIVE_USER" "$group"
	fi
done

#################################################################
#		install kernel and extra modules		#
#################################################################
cat_file kernelimg	/etc/kernel-img.conf

install_linux_kernel "$FLL_BUILD_LINUX_KERNEL"

chroot_exec dpkg --purge live-initrd-sidux busybox-sidux

#################################################################
#		preseed chroot					#
#################################################################
chroot_exec sed -i s/id\:[0-6]\:initdefault\:/id\:5\:initdefault\:/ /etc/inittab

if exists_in_chroot /usr/sbin/fix-fonts; then
	chroot_exec fix-fonts
fi

cat_file hosts		/etc/hosts
cat_file apt_sources	/etc/apt/sources.list
cat_file sudoers	/etc/sudoers

#################################################################
#		prepare result staging directory		#
#################################################################
mkdir -vp "${FLL_BUILD_RESULT}${FLL_MOUNTPOINT}"

# add templates (grub menu.lst/documentation/manual/autorun etc.)
for dir in "$FLL_BUILD_TEMPLATES"/common "$FLL_BUILD_TEMPLATES"/"$FLL_DISTRO_NAME"; do
	[[ -d $dir ]] || continue
	pushd $dir >/dev/null
		find . -not -path '*.svn*' -printf '%P\n' | \
			cpio -admpv --no-preserve-owner "$FLL_BUILD_RESULT"
	popd >/dev/null
done

# populate /boot
cp -vL "$FLL_BUILD_CHROOT"/boot/miniroot.gz "$FLL_BUILD_RESULT"/boot/miniroot.gz
cp -vL "$FLL_BUILD_CHROOT"/boot/vmlinuz "$FLL_BUILD_RESULT"/boot/vmlinuz
cp -v "$FLL_BUILD_CHROOT"/usr/lib/grub/*-pc/{iso9660_stage1_5,stage2_eltorito,stage2} \
	"$FLL_BUILD_RESULT"/boot/grub/
cp -v "$FLL_BUILD_CHROOT"/boot/message.live "$FLL_BUILD_RESULT"/boot/message

# md5sums
pushd "$FLL_BUILD_RESULT" >/dev/null
	( find . -type f -not \( -name '*md5sums' -o -name '*.cat' \) -printf '%P\n' | \
		sort | xargs md5sum -b ) > "$FLL_IMAGE_DIR"/md5sums
popd >/dev/null

#################################################################
#		unpatch chroot					#
#################################################################
chroot_exec apt-get clean

# add version marker, this is the exact time stamp for our package list
printf "$FLL_DISTRO_NAME $FLL_DISTRO_VERSION" \
	> "$FLL_BUILD_CHROOT/etc/${FLL_DISTRO_NAME_LC}-version"
printf " - $FLL_DISTRO_CODENAME ($PACKAGE_TIMESTAMP)" \
	>> "$FLL_BUILD_CHROOT/etc/${FLL_DISTRO_NAME_LC}-version"

remove_from_chroot /etc/kernel-img.conf
remove_from_chroot /usr/sbin/policy-rc.d
remove_from_chroot /etc/debian_chroot
remove_from_chroot /etc/hosts
remove_from_chroot /etc/resolv.conf
remove_from_chroot /etc/apt/apt.conf
remove_from_chroot /boot/miniroot.gz
remove_from_chroot "/boot/initrd.img*"
remove_from_chroot "/etc/ssh/ssh_host_*key*"
remove_from_chroot "/var/lib/dpkg/*-old"
remove_from_chroot "/var/cache/debconf/*-old"

find "$FLL_BUILD_CHROOT"/var/lib/apt/lists/ -not -name 'lock' -type f -exec rm -vf {} \;

rm -vrf "$FLL_BUILD_CHROOT"/var/cache/bootstrap

rmdir -v "${FLL_BUILD_CHROOT}${FLL_MOUNTPOINT}"

virtfs umount

#################################################################
if [[ $FLL_BUILD_CHROOT_ONLY ]]; then
	exit 0
fi
#################################################################

#################################################################
#		compress fs					#
#################################################################
make_compressed_image

#################################################################
#		create iso					#
#################################################################
make_fll_iso

exit 0

