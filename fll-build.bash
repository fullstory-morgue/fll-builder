#!/bin/bash

# Copyright (C) 2006 Sidux Crew, http://www.sidux.com
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

while (($#)); do
	case "$1" in
		-c|--configfile)
			shift
			FLL_BUILD_ALT_CONFIG="$1"
			;;
		*)
			;;
	esac
	shift
done

# Allow lazy development and testing
if [[ -s $PWD/debian/changelog ]]; then
	FLL_BUILD_BASE="$PWD"
fi

# Source distro-defaults
source /etc/default/distro

# Source default configfile
FLL_BUILD_CONFIG="$FLL_BUILD_BASE/etc/fll-builder/fll-build.conf"
source "$FLL_BUILD_CONFIG"

# Source alternative configfile
if [[ -s $FLL_BUILD_ALT_CONFIG ]]; then
	source $FLL_BUILD_ALT_CONFIG
fi

# Source functions
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_SCRIPTS="$FLL_BUILD_BASE/usr/share/fll-builder/fll-build.d/*.bm"
FLL_BUILD_FUNCS="$FLL_BUILD_SHARED/functions.bm"
source "$FLL_BUILD_FUNCS"

# Source all the scriptlets
for fll_script in $FLL_BUILD_SCRIPTS; do
	source $fll_script
done

exit 0
