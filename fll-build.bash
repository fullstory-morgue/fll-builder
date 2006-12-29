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

EOF
}

error() {
	echo -ne "$SELF error: "
	
	case $1 in
		1)
			echo "must be executed as root"
			;;
		2)
			echo "getopt failed"
			;;
		3)
			echo "invalid command line option"
			;;
		4)
			echo "unable to source alternate configfile"
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
(( UID )) && exec su-me "$0" "$@"

#################################################################
#		constant variable declarations			#
#################################################################
# script name and version info
SELF="fll-build"

# host arch
DPKG_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Allow lazy development and testing
[[ -s ./debian/changelog ]] && FLL_BUILD_BASE="."

# fll defaults
FLL_BUILD_DEFAULTS="$FLL_BUILD_BASE/etc/default/distro"

# fll default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"
FLL_BUILD_PACKAGELIST="$FLL_BUILD_BASE/etc/fll-builder/packages.conf"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.bm"

#################################################################
#		source configfiles and functions.sh		#
#################################################################
source "$FLL_BUILD_DEFAULTS"
source "$FLL_BUILD_CONFIG"
source "$FLL_BUILD_FUNCTIONS"
source "$FLL_BUILD_PACKAGELIST"

#################################################################
#		parse command line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--options b:c:dhko:vV \
		--long buildarea,configfile,debug,help,keep,output,verbose,version \
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

# temporary staging areas within buildarea, plus iso output
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

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		main						#
#################################################################
set -e

set | grep ^FLL_

cdebootstrap_chroot

create_chroot_policy
create_debian_chroot
create_interfaces
create_fstab
create_sources_list working
copy_to_chroot /etc/hosts
copy_to_chroot /etc/resolv.conf

virtfs mount

# XXX: distro-defaults live environment detection
chroot_exec mkdir -vp "$FLL_MOUNTPOINT"

chroot_exec apt-get update
chroot_exec apt-get --allow-unauthenticated --assume-yes install sidux-keyrings
chroot_exec apt-get update
chroot_exec apt-get --assume-yes install distro-defaults
chroot_exec apt-get --assume-yes install ${FLL_PACKAGES[@]}

chroot_exec adduser --no-create-home --disabled-password \
	--gecos "$FLL_LIVE_USER" "$FLL_LIVE_USER"

for group in $FLL_LIVE_USER_GROUPS; do
	if chroot_exec getent group "$group"; then
		chroot_exec adduser "$FLL_LIVE_USER" "$group"
	fi
done

install_linux_kernel

chroot_exec rmdir -v "$FLL_MOUNTPOINT"

virtfs umount

remove_from_chroot /usr/sbin/policy-rc.d
remove_from_chroot /etc/debian_chroot
remove_from_chroot /etc/hosts
remove_from_chroot /etc/resolv.conf

create_sources_list final
create_sudoers

if [[ $FLL_BUILD_CHROOT_ONLY ]]; then
	exit 0
fi

#make_compressed_image

#make_fll_iso

exit 0
