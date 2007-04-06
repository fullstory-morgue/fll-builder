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

# package profile dir and default
FLL_BUILD_PACKAGE_PROFDIR="$FLL_BUILD_BASE/etc/fll-builder/packages"
FLL_BUILD_PACKAGE_PROFILE="kde-lite"

# fll script and template location variables
FLL_BUILD_SHARED="$FLL_BUILD_BASE/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="$FLL_BUILD_SHARED/functions.d"
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

	FLL_BUILD_ARCH="$DPKG_ARCH"

	source "$config"

	if [[ ! $FLL_BUILD_LINUX_KERNEL ]]; then
		echo "$SELF: you must define FLL_BUILD_LINUX_KERNEL in the config!"
		echo
		print_help
		exit 4
	fi

	if [[ $FLL_HTTP_PROXY ]]; then
		export http_proxy=$FLL_HTTP_PROXY
	fi

	if [[ $FLL_FTP_PROXY ]]; then
		export ftp_proxy=$FLL_FTP_PROXY
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
	FLL_BUILD_TEMP=$(mktemp -p $FLL_BUILD_AREA -d $SELF.XXXXX)
	FLL_BUILD_CHROOT="$FLL_BUILD_TEMP/CHROOT"
	FLL_BUILD_RESULT="$FLL_BUILD_TEMP/RESULT"

	mkdir -vp "$FLL_BUILD_CHROOT" "$FLL_BUILD_RESULT/boot" "${FLL_BUILD_RESULT}${FLL_MOUNTPOINT}"

	# fix permissions to allow user access
	if [[ $FLL_BUILD_OUTPUT_UID != 0 ]]; then
		for dir in "$FLL_BUILD_AREA" "$FLL_BUILD_TEMP" "$FLL_BUILD_CHROOT" "$FLL_BUILD_RESULT"; do
			chown "${FLL_BUILD_OUTPUT_UID}:${FLL_BUILD_OUTPUT_UID}" "$dir"
		done
	fi

	#################################################################
	#		create & prepare chroot				#
	#################################################################
	if [[ $DEBOOTSTRAP_ARCH ]]; then
		echo "DEBOOTSTRAP_ARCH is not used anymore!"
		echo "Time to look at $FLL_BUILD_DEFCONFIG"
		exit 999
	fi

	cdebootstrap --arch="$FLL_BUILD_ARCH" --flavour=minimal sid \
		"$FLL_BUILD_CHROOT" "$FLL_BUILD_DEBIANMIRROR"
	
	chroot_virtfs mount

	cat_file_to_chroot chroot_policy	/usr/sbin/policy-rc.d
	cat_file_to_chroot debian_chroot	/etc/debian_chroot
	cat_file_to_chroot fstab		/etc/fstab
	cat_file_to_chroot interfaces		/etc/network/interfaces
	cat_file_to_chroot apt_sources_tmp	/etc/apt/sources.list
	cat_file_to_chroot apt_conf		/etc/apt/apt.conf
	
	copy_to_chroot /etc/hosts
	copy_to_chroot /etc/resolv.conf
	
	# distro-defaults live environment detection
	mkdir -vp "${FLL_BUILD_CHROOT}${FLL_MOUNTPOINT}"
	
	chroot_exec apt-get update
	
	# import key for extra mirror(s)
	for ((i=0; i<=${#FLL_BUILD_EXTRAMIRROR[@]}; i++)); do
		[[ ${FLL_BUILD_EXTRAMIRROR[$i]} ]] || continue
		if [[ ${FLL_BUILD_EXTRAMIRROR_GPGKEYID[$i]} ]]; then
			echo "Importing GPG key for ${FLL_BUILD_EXTRAMIRROR[$i]}"
			chroot_exec gpg --keyserver wwwkeys.eu.pgp.net --recv-keys \
				"${FLL_BUILD_EXTRAMIRROR_GPGKEYID[$i]}" | :
		else
			echo "Must provide GPG keyid for ${FLL_BUILD_EXTRAMIRROR[$i]}"
			exit 6
		fi
	done

	# add imported gpg keys to apt's trusted keyring
	if exists_in_chroot /root/.gnupg/pubring.gpg; then
		chroot_exec apt-key add /root/.gnupg/pubring.gpg
	fi

	# refresh lists now that "secure apt" is aware of required gpg keys
	chroot_exec apt-get update
	
	# package timestamp for snapshot versioning
	FLL_PACKAGE_TIMESTAMP="$(date -u +%Y%m%d%H%M)"
	
	# ensure distro-defaults is present
	chroot_exec apt-get --assume-yes install distro-defaults
	
	#################################################################
	#	preseed locales						#
	#################################################################
	chroot_exec apt-get --assume-yes install debconf
	echo "locales	locales/default_environment_locale	select	en_US.UTF-8" | chroot_exec debconf-set-selections
	echo "locales	locales/locales_to_be_generated	multiselect	be_BY.UTF-8 UTF-8, bg_BG.UTF-8 UTF-8, cs_CZ.UTF-8 UTF-8, da_DK.UTF-8 UTF-8, de_CH.UTF-8 UTF-8, de_DE.UTF-8 UTF-8, el_GR.UTF-8 UTF-8, en_AU.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, en_IE.UTF-8 UTF-8, en_US.UTF-8 UTF-8, es_ES.UTF-8 UTF-8, fi_FI.UTF-8 UTF-8, fr_FR.UTF-8 UTF-8, fr_BE.UTF-8 UTF-8, ga_IE.UTF-8 UTF-8, he_IL.UTF-8 UTF-8, hr_HR.UTF-8 UTF-8, hu_HU.UTF-8 UTF-8, it_IT.UTF-8 UTF-8, ja_JP.UTF-8 UTF-8, ko_KR.UTF-8 UTF-8, nl_NL.UTF-8 UTF-8, nl_BE.UTF-8 UTF-8, pl_PL.UTF-8 UTF-8, pt_BR.UTF-8 UTF-8, pt_PT.UTF-8 UTF-8, ru_RU.UTF-8 UTF-8, sk_SK.UTF-8 UTF-8, sl_SI.UTF-8 UTF-8, tr_TR.UTF-8 UTF-8, zh_CN.UTF-8 UTF-8, zh_TW.UTF-8 UTF-8" | chroot_exec debconf-set-selections
	chroot_exec apt-get --assume-yes install locales

	#################################################################
	#	install kernel, make initial ramdisk			#
	#################################################################
	# module-init-tools required for depmod, it may not be in minimal bootstrap
	chroot_exec apt-get --assume-yes install live-initrd-sidux module-init-tools
	
	cat_file_to_chroot kernelimg /etc/kernel-img.conf
	install_linux_kernel "$FLL_BUILD_LINUX_KERNEL"
	
	#################################################################
	#	mass package installation				#
	#################################################################
	chroot_exec apt-get --assume-yes install ${FLL_PACKAGES[@]}
	
	echo
	echo "Calculating source package URI list . . ."
	echo
	fetch_source_uris
	
	# XXX: this hack is FOR TESTING PURPOSES ONLY
	if [[ $FLL_BUILD_LOCAL_DEBS ]]; then
		install_local_debs "$FLL_BUILD_LOCAL_DEBS"
	fi
	
	#################################################################
	#	create user in chroot					#
	#################################################################
	chroot_exec adduser --no-create-home --disabled-password \
		--gecos "$FLL_LIVE_USER" "$FLL_LIVE_USER"
	
	# add to groups, check if group exists first
	for group in $FLL_LIVE_USER_GROUPS; do
		if chroot_exec getent group "$group"; then
			chroot_exec adduser "$FLL_LIVE_USER" "$group"
		fi
	done
	
	# lock down root and live user
	sed -i "s#^\(root\|$FLL_LIVE_USER\):.*:\(.*:.*:.*:.*:.*:.*:.*\)#\1:\*:\2#" \
		"$FLL_BUILD_CHROOT"/etc/shadow

	#################################################################
	#	hack inittab						#
	#		- init 5 by default				#
	#		- immutable bash login shells			#
	#################################################################
	sed -i	-e 's#^id:[0-6]:initdefault:#id:5:initdefault:#' \
		-e 's#^\(~~:S:wait:\).\+#\1/bin/bash\ -login\ >/dev/tty1\ 2>\&1\ </dev/tty1#' \
		-e 's#^\(1\):\([0-9]\+\):\(respawn\):.\+#\1:\2:\3:/bin/bash\ -login\ >/dev/tty\1\ 2>\&1\ </dev/tty\1#' \
		-e 's#^\([2-6]\):\([0-9]\+\):\(respawn\):.\+#\1:\245:\3:/bin/bash\ -login\ >/dev/tty\1\ 2>\&1\ </dev/tty\1#' \
		"$FLL_BUILD_CHROOT"/etc/inittab
	
	#################################################################
	#	misc chroot preseeding					#
	#################################################################
	# run fix-fonts
	if exists_in_chroot /usr/sbin/fix-fonts; then
		chroot_exec fix-fonts
	fi
	
	# set x-www-browser, use the popular firefox/iceweasel if present
	if exists_in_chroot /usr/bin/iceweasel; then
		chroot_exec update-alternatives --set x-www-browser /usr/bin/iceweasel
	elif exists_in_chroot /usr/bin/epiphany-browser; then
		chroot_exec update-alternatives --set x-www-browser /usr/bin/epiphany-browser
	elif exists_in_chroot /usr/bin/konqueror; then
		chroot_exec update-alternatives --set x-www-browser /usr/bin/konqueror
	fi
	
	# use most as PAGER if installed in chroot
	if exists_in_chroot /usr/bin/most; then
		chroot_exec update-alternatives --set pager /usr/bin/most
	fi
	
	# vimrc.local
	if exists_in_chroot /etc/vim; then
		cat_file_to_chroot vimrc_local /etc/vim/vimrc.local
	fi

	# kppp noauth setting (as per /usr/share/doc/kppp/README.Debian)
	if exists_in_chroot /etc/ppp/peers/kppp-options; then
		sed -i 's/^#\?noauth/noauth/' "$FLL_BUILD_CHROOT"/etc/ppp/peers/kppp-options
	fi
	
	#################################################################
	#	cleanup & prepare final chroot				#
	#################################################################
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
	
	# add version marker, this is the exact time stamp for our package list
	echo -n "$FLL_DISTRO_NAME $FLL_DISTRO_VERSION" \
		> "$FLL_BUILD_CHROOT/etc/${FLL_DISTRO_NAME_LC}-version"
	echo " - $FLL_DISTRO_CODENAME ($FLL_PACKAGE_TIMESTAMP)" \
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

	chroot_virtfs umount

	[[ $FLL_BUILD_CHROOT_ONLY ]] && continue

	#################################################################
	#		build						#
	#################################################################

	# add templates (grub menu.lst/documentation/manual/autorun etc.)
	for dir in "$FLL_BUILD_TEMPLATES"/common "$FLL_BUILD_TEMPLATES"/"$FLL_DISTRO_NAME"; do
		[[ -d $dir ]] || continue
		pushd $dir >/dev/null
			find . -not -path '*.svn*' -printf '%P\n' | \
				cpio -admpv --no-preserve-owner "$FLL_BUILD_RESULT"
		popd >/dev/null
	done

	# populate /boot/
	cp -vL "$FLL_BUILD_CHROOT"/boot/miniroot.gz "$FLL_BUILD_RESULT"/boot/miniroot.gz
	cp -vL "$FLL_BUILD_CHROOT"/boot/vmlinuz "$FLL_BUILD_RESULT"/boot/vmlinuz

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

	make_compressed_image

	# md5sums
	pushd "$FLL_BUILD_RESULT" >/dev/null
		find .	\
			-type f \
			-not \( \
				-name '*md5sums' \
				-o -name '*.cat' \
				-o -name 'iso9660_stage1_5' \
				-o -name 'stage2_eltorito' \
			\) \
			-printf '%P\n' | sort | xargs md5sum -b > "$FLL_IMAGE_DIR"/md5sums
	popd >/dev/null

	if [[ ! -d $FLL_BUILD_ISO_DIR ]]; then
		if [[ $FLL_BUILD_ISO_DIR ]]; then
			echo "$SELF: $FLL_BUILD_ISO_DIR does not exist!"
			echo "$SELF: creating iso in ../$FLL_BUILD_AREA"
		fi
		FLL_BUILD_ISO_DIR=../"$FLL_BUILD_AREA"
	fi

	make_fll_iso "$FLL_BUILD_ISO_DIR"

	# if started as user, apply user ownership to output (based on --uid)
	if [[ $FLL_BUILD_OUTPUT_UID != 0 ]]; then
		chown "${FLL_BUILD_OUTPUT_UID}:${FLL_BUILD_OUTPUT_UID}" \
			"$FLL_BUILD_ISO_DIR"/"$FLL_ISO_NAME"*
	fi

	nuke_buildarea
done

exit 0
