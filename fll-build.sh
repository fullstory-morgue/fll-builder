#!/bin/sh

# Copyright (C) 2006 Sidux Crew, http://www.sidux.com
#	Stefan Lippers-Hollmann <s.l-h@gmx.de>
#	Niall Walsh <niallwalsh@users.berlios.de>
#	Kel Modderman <kel@otaku42.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this package; if not, write to the Free Software 
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, 
# MA 02110-1301, USA.
#
# On Debian GNU/Linux systems, the text of the GPL license can be
# found in /usr/share/common-licenses/GPL.

#################################################################
#		Synopsis					#
#################################################################
# fll-build(8): build a debian 'sid' live linux cd that uses code
# developed by members of the F.U.L.L.S.T.O.R.Y project to enhance
# hardware detection and linux experience.
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
#		Variable Declarations				#
#################################################################
# script name and version info
VERSION="0.0.0"
SELF=$(basename $0)

# Allow lazy development and testing
[ -s ./debian/changelog ] && FLL_BUILD_BASE="."

# defaults
FLL_BUILD_DEFAULTS="/etc/default/distro"

# default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"

# fll functions
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_SCRIPTDIR="$FLL_BUILD_BASE/usr/share/fll-builder/fll-build.d"
FLL_BUILD_FUNCS="$FLL_BUILD_SHARED/functions.sh"

#################################################################
#		Source configfiles and functions.sh		#
#################################################################
. "$FLL_BUILD_DEFAULTS"
. "$FLL_BUILD_CONFIG"
. "$FLL_BUILD_FUNCS"

#################################################################
#		Parse Command Line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--shell sh \
		--options c:hv \
		--long configfile,help,version \
		-- $@
)

if [ $? = 0 ]; then
	eval set -- "$ARGS"
else
	echo "getopt failed, terminating..." >&2
	exit 1
fi

while true; do
	case "$1" in
		-c|--configfile)
			shift
			FLL_BUILD_ALT_CONFIG="$1"
			;;
		-h|--help)
			print_help
			exit 0
			;;
		-v|--version)
			print_version
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			;;
	esac
	shift
done

#################################################################
#		Process Command Line Options			#
#################################################################
# alternate configfile
if [ "$FLL_BUILD_ALT_CONFIG" ]; then
	if [ -s "$FLL_BUILD_ALT_CONFIG" ]; then
		. "$FLL_BUILD_ALT_CONFIG"
	else
		echo "Cannot source alternate configfile: $FLL_BUILD_ALT_CONFIG" >&2
		exit 1
	fi
fi

#################################################################
#		Debug()						#
#################################################################
if [ "$DEBUG" -gt 0 ]; then
	set | grep ^FLL
fi

#################################################################
#		Main()						#
#################################################################
# source all the fll scriptlets
for fll_script in "$FLL_BUILD_SCRIPTDIR"/*.sh; do
	[ -s "$fll_script" ] && . "$fll_script"
done

exit 0
