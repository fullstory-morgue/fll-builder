#!/bin/bash

print_copyright() {
	cat <<EOF

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
	cat <<EOF

Usage: $SELF [options]

Options:
  -b|--buildarea	Path to temporary build area for live-cd chroot
  (default: /var/cache/fll-builder)

  -c|--configfile	Path to alternate configfile
  (default: /etc/fll-builder/fll-build.conf)

  -d|--debug		Debug shell code execution (set -x)

  -h|--help		Information about using this program

  -v|--verbose		Verbose informational output

  -V|--version		Version and copyright information

EOF
}

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

set -e

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

# Allow lazy development and testing
[[ -s ./debian/changelog ]] && FLL_BUILD_BASE="."

# fll defaults
FLL_BUILD_DEFAULTS="/etc/default/distro"

# fll default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_SCRIPTDIR="$FLL_BUILD_SHARED/fll-build.d"
FLL_BUILD_TEMPLATEDIR="$FLL_BUILD_SHARED/templates"
FLL_BUILD_ERROR="$FLL_BUILD_SHARED/commonerror.bm"
FLL_BUILD_FUNCS="$FLL_BUILD_SHARED/functions.bm"

FLL_BUILD_AREA="/var/cache/fll-builder"

#################################################################
#		source configfiles and functions.sh		#
#################################################################
source $FLL_BUILD_DEFAULTS
source $FLL_BUILD_CONFIG
source $FLL_BUILD_ERROR
source $FLL_BUILD_FUNCS

#################################################################
#		parse command line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--shell sh \
		--options b:c:dhvV \
		--long buildarea,configfile,debug,help,verbose,version \
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
if [[ -d $FLL_BUILD_AREA ]]; then
	unset TMPDIR
	FLL_BUILD_CHROOT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
	FLL_BUILD_RESULT=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
else
	error 4
fi

#################################################################
#		Debug Environment				#
#################################################################
[[ $VERBOSE -gt 0 ]] && set | grep ^FLL_

#################################################################
#		Main()						#
#################################################################
# source all the fll scriptlets
for fll_script in "$FLL_BUILD_SCRIPTDIR"/[0-9][0-9][0-9]*.bm; do
	[[ -s $fll_script ]] && source $fll_script
done

exit 0
