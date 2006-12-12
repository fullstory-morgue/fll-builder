#!/bin/bash

set -e

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

  -d|--debug		Debug shell code execution (set -x)

  -h|--help		Information about using this program

  -k|--keep		Preserve build area when finished

  -v|--verbose		Verbose informational output

  -V|--version		Version and copyright information

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
			echo "unable to create buildarea"
			;;
		6)
			echo "buildarea target not specified"
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
VERSION="0.0.0"

# Required for installation of some packages
LANG=C
LC_ALL=C
export LANG LC_ALL

# host arch
DPKG_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Allow lazy development and testing
[[ -s ./debian/changelog ]] && FLL_BUILD_BASE="."

# fll defaults
FLL_BUILD_DEFAULTS="/etc/default/distro"

# fll default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_TEMPLATEDIR="$FLL_BUILD_SHARED/templates"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.bm"

#################################################################
#		source configfiles and functions.sh		#
#################################################################
source $FLL_BUILD_DEFAULTS
source $FLL_BUILD_CONFIG
source $FLL_BUILD_FUNCTIONS

#################################################################
#		parse command line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--shell sh \
		--options b:c:dhkvV \
		--long buildarea,configfile,debug,help,keep,verbose,version \
		-- $@
)

[[ $? = 0 ]] || error 1

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
		-d|--debug)
			set -x
			;;
		-h|--help)
			print_help
			exit 0
			;;
		-k|--keep)
			FLL_BUILD_KEEPCHROOT=1
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-V|--version)
			echo "$SELF (Version: $VERSION)"
			print_copyright
			exit 0
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
		source $FLL_BUILD_ALT_CONFIG
	else
		error 3
	fi
fi

# temporary staging areas within buildarea
if [[ $FLL_BUILD_AREA ]]; then
	mkdir -p $FLL_BUILD_AREA || error 4
	unset TMPDIR
	FLL_BUILD_CHROOT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
	FLL_BUILD_RESULT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
else
	# must provide --buildarea or FLL_BUILD_AREA
	# there is no sane default
	error 5
fi

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		debug environment				#
#################################################################
if [[ $VERBOSE -gt 0 ]]; then
	set | grep -E '^(FLL|DEBOOTSTRAP)'
fi

#################################################################
#		main()						#
#################################################################

strap_chroot
# cleanup unrequired packages (from live-package)
chroot_exec "dpkg --purge cdebootstrap-helper-diverts"

patch_chroot pre

proc mount

proc umount

patch_chroot post

exit 0
