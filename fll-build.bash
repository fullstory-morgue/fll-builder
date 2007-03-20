#!/bin/bash -e

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

Usage: $SELF [options] <build_directory>

Arguments:
  $SELF takes only one argument; path to build directory. A writeable
  directory must be provided as the first and only argument (after options).

Options:
  -c|--configfile		Path to alternate configfile
  				(default: /etc/fll-builder/fll-build.conf)

  -C|--copyright		Copyright information

  -d|--debug			Debug shell code execution (set -x)

  -h|--help			Information about using this program

  -n|--chroot-only		Quit after preparing chroot

  -o|--output			Directory to output the build product

  -p|--preserve			Preserve build area when finished

EOF
}

#################################################################
#		root?						#
#################################################################
if (($UID)); then
	DISPLAY= exec su-me "$0 --uid $UID" "$@"
fi

#################################################################
#		language agnostic				#
#################################################################
LANG=C
LC_ALL=C
export LANG LC_ALL

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
source "$FLL_BUILD_DEFAULTS"

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

# fll default configfile
FLL_BUILD_DEFCONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"

# package profile dir
FLL_BUILD_PACKAGE_PROFDIR="$FLL_BUILD_BASE/etc/fll-builder/packages"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.d"
FLL_BUILD_BUILDD="$FLL_BUILD_SHARED/build.d"
FLL_BUILD_TEMPLATES="$FLL_BUILD_SHARED/templates"
FLL_BUILD_EXCLUSION_LIST="$FLL_BUILD_SHARED/exclusion_list"

# store current UID, override later if executed by !root
FLL_BUILD_OUTPUT_UID=$UID

#################################################################
#		source functions				#
#################################################################
for func in "$FLL_BUILD_FUNCTIONS"/*.bm; do
	source "$func"
done

#################################################################
#		parse command line				#
#################################################################
ARGS=$( getopt --name "$SELF" \
	--options c:Cdhno:p \
	--long configfile:,chroot-only,copyright,debug,help,output,preserve,uid: \
	-- $@ )

if [[ $? != 0 ]]; then
	echo "$SELF: getopt failed, terminating."
	exit 1
fi

eval set -- "$ARGS"

while true; do
	case $1 in
		-c|--configfile)
			shift
			FLL_BUILD_CONFIGS+=( $1 )
			;;
		-C|--copyright)
			print_copyright
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			set -x
			;;
		-h|--help)
			print_help
			exit 0
			;;
		-n|--chroot-only)
			FLL_BUILD_CHROOT_ONLY=1
			;;
		-o|--output)
			shift
			FLL_BUILD_ISO_DIR=$1
			;;
		-p|--preserve)
			FLL_BUILD_PRESERVE_CHROOT=1
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
			echo "$SELF: invalid command line option"
			echo
			print_help
			exit 2
			;;
	esac
	shift
done

if [[ $1 ]]; then
	FLL_BUILD_AREA="$1"
	mkdir -p "$FLL_BUILD_AREA"
else
	echo "$SELF: must supply a build directory as first and only command line argument!"
	echo
	print_help
	exit 3
fi

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		source local config(s)				#
#################################################################
# alternate configfile
if [[ ! ${FLL_BUILD_CONFIGS[@]} ]]; then
	FLL_BUILD_CONFIGS=( $FLL_BUILD_DEFCONFIG )
fi

for config in ${FLL_BUILD_CONFIGS[@]}; do
	if [[ $config != $FLL_BUILD_DEFCONFIG ]]; then
		# restore defaults for each build
		source "$FLL_BUILD_DEFCONFIG"
	fi

	DEBOOTSTRAP_ARCH="$DPKG_ARCH"

	source "$config"

	if [[ ! $FLL_BUILD_LINUX_KERNEL ]]; then
		echo "$SELF: you must define FLL_BUILD_LINUX_KERNEL in the config!"
		echo
		print_help
		exit 4
	fi

	#################################################################
	#		process package array(s)			#
	#################################################################
	source_package_profile "$FLL_BUILD_PACKAGE_PROFILE"

	if [[ ! ${FLL_PACKAGES[@]} ]]; then
		echo "$SELF: package profile did not produce FLL_PACKAGES array!"
		exit 5
	fi
	
	# echo package list early for bfree :-)
	echo "${FLL_PACKAGES[@]}"

	#################################################################
	#		prepare build area				#
	#################################################################
	# temporary staging areas within buildarea
	FLL_BUILD_TEMP=$(mktemp -p $FLL_BUILD_AREA -d $SELF.TEMP.XXXXX)
	FLL_BUILD_CHROOT="$FLL_BUILD_TEMP/CHROOT"
	FLL_BUILD_RESULT="$FLL_BUILD_TEMP/RESULT"

	mkdir -vp "$FLL_BUILD_CHROOT" "$FLL_BUILD_RESULT/boot" "${FLL_BUILD_RESULT}${FLL_MOUNTPOINT}"

	if [[ $FLL_BUILD_OUTPUT_UID != 0 ]]; then
		for dir in "$FLL_BUILD_AREA" "$FLL_BUILD_TEMP" "$FLL_BUILD_CHROOT" "$FLL_BUILD_RESULT"; do
			chown "$FLL_BUILD_OUTPUT_UID":"$FLL_BUILD_OUTPUT_UID" "$dir"
		done
	fi

	##################################################################
	#		chroot						#
	#################################################################
	cdebootstrap --arch="$DEBOOTSTRAP_ARCH" --flavour="$DEBOOTSTRAP_FLAVOUR" \
		"$DEBOOTSTRAP_DIST" "$FLL_BUILD_CHROOT" "$DEBOOTSTRAP_MIRROR"
	
	chroot_virtfs mount

	run_scripts "$FLL_BUILD_BUILDD"/chroot

	chroot_virtfs umount

	[[ $FLL_BUILD_CHROOT_ONLY ]] && continue

	#################################################################
	#		build						#
	#################################################################
	run_scripts "$FLL_BUILD_BUILDD"/build

	nuke_buildarea
done

exit 0
