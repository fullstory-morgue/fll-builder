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

set -e

#################################################################
#		constant variable declarations			#
#################################################################
# script name and version info
SELF="fll-build"
VERSION="0.0.0"

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
FLL_BUILD_FUNCS="$FLL_BUILD_SHARED/functions.bm"

#################################################################
#		source configfiles and functions.sh		#
#################################################################
source $FLL_BUILD_DEFAULTS
source $FLL_BUILD_CONFIG
source $FLL_BUILD_FUNCS

#################################################################
#		parse command line				#
#################################################################
ARGS=$(
	getopt \
		--name "$SELF" \
		--shell sh \
		--options b:c:hv \
		--long buildarea,configfile,help,version \
		-- $@
)

if [[ $? = 0 ]]; then
	eval set -- "$ARGS"
else
	error 1
fi

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
		-h|--help)
			print_help
			exit 0
			;;
		-v|--version)
			print_version
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

# local buildarea
: ${FLL_BUILD_AREA:="/var/cache/fll-builder"}

[[ -d $FLL_BUILD_AREA ]] || error 4

unset TMPDIR
FLL_BUILD_CHROOT=$(mktemp -p $FLL_BUILD_AREA $SELF.XXXXX)
FLL_BUILD_RESULT=$(mktemp -p $FLL_BUILD_AREA $SELF.XXXXX)

#################################################################
#		Debug Environment						#
#################################################################
[[ $DEBUG -gt 0 ]] && set | grep ^FLL_

#################################################################
#		Main()						#
#################################################################
# source all the fll scriptlets
for fll_script in "$FLL_BUILD_SCRIPTDIR"/*.bm; do
	[[ -s $fll_script ]] && source $fll_script
done

exit 0
