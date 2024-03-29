#!/bin/bash -e

echo 'This script is no longer maintained, Aborting!'
exit 1

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

Copyright (C) 2006 - 2007 Kel Modderman <kel@otaku42.de>
          (C) 2006 - 2007 Stefan Lippers-Hollmann <s.l-h@gmx.de>

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

Usage: ${SELF} [options] <build_directory>

Arguments:
  ${SELF} takes only one argument; path to build directory. A writeable
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

  -P|--package-profiledir	Package profile directory

  -B|--binary-release		Build binary product only

  -S|--source-release		Create source code URI list for release

  -t|--template-dir		Path to alternate Live CD root template dir


EOF
}

#################################################################
#		root?						#
#################################################################
if ((UID)); then
	exec su root -c "${0} --uid ${UID} $*"
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
FLL_BUILD_BASE=$(dirname ${0})
if [[ ! -f  ${FLL_BUILD_BASE}/debian/changelog ]]; then
	unset FLL_BUILD_BASE
fi

# fll defaults
FLL_BUILD_DEFAULTS="${FLL_BUILD_BASE}/etc/default/distro"
source "${FLL_BUILD_DEFAULTS}"

# distro name, lower casified
FLL_DISTRO_NAME_LC="$(tr [:upper:] [:lower:] <<< ${FLL_DISTRO_NAME})"
# distro name, upper casified
FLL_DISTRO_NAME_UC="$(tr [:lower:] [:upper:] <<< ${FLL_DISTRO_NAME})"

# check for ${FLL_DISTRO_CODENAME}
if [[ -z ${FLL_DISTRO_CODENAME} ]]; then
	FLL_DISTRO_CODENAME="snapshot"
fi

# set ${FLL_DISTRO_CODENAME_SAFE}, if undefined
if [[ -z ${FLL_DISTRO_CODENAME_SAFE} ]]; then
	FLL_DISTRO_CODENAME_SAFE="$(sed s/\ /_/g <<< ${FLL_DISTRO_CODENAME})"
fi

# fll default configfile
FLL_BUILD_DEFCONFIG="${FLL_BUILD_BASE}/etc/fll-builder/fll-build.conf"

# package profile dir and default
FLL_BUILD_PACKAGE_PROFDIR="${FLL_BUILD_BASE}/etc/fll-builder/packages"
FLL_BUILD_PACKAGE_PROFILE="kde-lite"

# fll script and template location variables
FLL_BUILD_SHARED="${FLL_BUILD_BASE}/usr/share/fll-builder"
FLL_BUILD_FUNCTIONS="${FLL_BUILD_SHARED}/functions.d"
FLL_BUILD_TEMPLATES="${FLL_BUILD_SHARED}/templates"
FLL_BUILD_EXCLUSION_LIST="${FLL_BUILD_SHARED}/exclusion_list"

# squashfs compression
if [[ -z ${FLL_BUILD_SQUASHFS_COMPRESSION} ]]; then
	FLL_BUILD_SQUASHFS_COMPRESSION="zlib"
fi

# store current UID, override later if executed by !root
FLL_BUILD_OUTPUT_UID=${UID}

# create source uri + manifest by default
FLL_SOURCE_RELEASE=1

#################################################################
#		source functions				#
#################################################################
for func in "${FLL_BUILD_FUNCTIONS}"/*.bm; do
	source "${func}"
done

#################################################################
#		parse command line				#
#################################################################
ARGS=$( getopt --name "${SELF}" \
	--options Bc:Cdhno:pP:St: \
	--long binary-release,configfile:,chroot-only,copyright,debug,help,output:,package-profiledir,preserve,source-release,template-dir:,uid: \
	-- $@ )

if [[ $? != 0 ]]; then
	echo "${SELF}: getopt failed, terminating."
	exit 1
fi

eval set -- "${ARGS}"

while true; do
	case ${1} in
		-B|--binary-release)
			((FLL_SOURCE_RELEASE--))
			;;
		-c|--configfile)
			shift
			FLL_BUILD_CONFIGS+=( ${1} )
			;;
		-C|--copyright)
			print_copyright
			exit 0
			;;
		-d|--debug)
			((DEBUG++))
			;;
		-h|--help)
			print_help
			exit 0
			;;
		-n|--chroot-only)
			((FLL_BUILD_CHROOT_ONLY++))
			;;
		-o|--output)
			shift
			FLL_BUILD_ISO_DIR=${1}
			;;
		-p|--preserve)
			((FLL_BUILD_PRESERVE_CHROOT++))
			;;
		-P|--package-profiledir)
			shift
			FLL_BUILD_PACKAGE_PROFDIR=${1}
			;;
		-S|--source-release)
			((FLL_SOURCE_RELEASE++))
			;;
		-t|--template-dir)
			shift
			FLL_BUILD_TEMPLATES=${1}
			;;
		--uid)
			# this need not be a documented feature
			shift
			FLL_BUILD_OUTPUT_UID=${1}
			;;
		--)
			shift
			break
			;;
		*)
			echo "${SELF}: invalid command line option"
			echo
			print_help
			exit 2
			;;
	esac
	shift
done

#################################################################
#		determine abs. dirname				#
#################################################################
if [[ ${1} ]]; then
	# make build dir and determine its absolute path
	mkdir -p ${1} && FLL_BUILD_AREA="$(absdirname ${1})"
else
	echo "${SELF}: must supply a build directory as first and only command line argument!"
	echo
	print_help
	exit 4
fi

if [[ ! ${FLL_BUILD_CONFIGS[@]} ]]; then
	echo "${SELF}: must supply a build configuration file"
	echo
	print_help
	exit 5
fi

if [[ ${DEBUG} -ge 2 ]]; then
	set -x
fi

#################################################################
#		clean up on exit				#
#################################################################
trap nuke_buildarea exit

#################################################################
#		source local config(s)				#
#################################################################
for config in ${FLL_BUILD_CONFIGS[@]}; do
	FLL_BUILD_ARCH="${DPKG_ARCH}"

	source "${config}"

	#################################################################
	#		export proxy env vars				#
	#################################################################
	if [[ ${FLL_HTTP_PROXY} ]]; then
		export http_proxy=${FLL_HTTP_PROXY}
	fi

	if [[ ${FLL_FTP_PROXY} ]]; then
		export ftp_proxy=${FLL_FTP_PROXY}
	fi

	# package timestamp for snapshot versioning
	FLL_PACKAGE_TIMESTAMP="$(date -u +%Y%m%d%H%M)"

	#################################################################
	#		iso name (with package timestamp)		#
	#################################################################
	if [ "${FLL_DISTRO_CODENAME}" = "snapshot" ]; then
		FLL_ISO_NAME="$(tr [:upper:] [:lower:] <<< \
				${FLL_DISTRO_NAME}-${FLL_PACKAGE_TIMESTAMP}-${FLL_DISTRO_CODENAME_SAFE}-${FLL_BUILD_PACKAGE_PROFILE}-$(tr [:blank:] \- <<< ${FLL_BUILD_ARCH[@]}).iso)"
	else
		FLL_ISO_NAME="$(tr [:upper:] [:lower:] <<< \
				${FLL_DISTRO_NAME}-${FLL_DISTRO_VERSION}-${FLL_PACKAGE_TIMESTAMP}-${FLL_DISTRO_CODENAME_SAFE}-${FLL_BUILD_PACKAGE_PROFILE}-$(tr [:blank:] \- <<< ${FLL_BUILD_ARCH[@]}).iso)"
	fi

	#################################################################
	#		prepare build area				#
	#################################################################
	# temporary staging areas within buildarea
	FLL_BUILD_TEMP=$(mktemp -p ${FLL_BUILD_AREA} -d ${SELF}.XXXXX)
	FLL_BUILD_RESULT="${FLL_BUILD_TEMP}/RESULT"
	mkdir -vp "${FLL_BUILD_RESULT}/boot" "${FLL_BUILD_RESULT}/${FLL_IMAGE_DIR}"

	header "Staging result area: ${FLL_BUILD_RESULT}"
	# add templates (grub menu.lst/documentation/manual/autorun etc.)
	for dir in "${FLL_BUILD_TEMPLATES}"/*; do
		[[ -d ${dir} ]] || continue
		pushd ${dir} >/dev/null
			find . -not -path '*.svn*' -printf '%P\n' | \
				cpio -Ladmpv --no-preserve-owner "${FLL_BUILD_RESULT}"
		popd >/dev/null
	done

	# fix permissions to allow user access
	if ((FLL_BUILD_OUTPUT_UID)); then
		chown "${FLL_BUILD_OUTPUT_UID}:${FLL_BUILD_OUTPUT_UID}" "${FLL_BUILD_AREA}"
		chown -R "${FLL_BUILD_OUTPUT_UID}:${FLL_BUILD_OUTPUT_UID}" "${FLL_BUILD_TEMP}"
	fi

	for arch in ${!FLL_BUILD_ARCH[@]}; do
		#################################################################
		#		arch specific name				#
		#################################################################
		# NOTE: we have to be very careful when redefining FLL_ variables
		# in a loop like this, make sure we strip the previously appended
		# FLL_IMAGE_FILE extension.
		FLL_IMAGE_FILE="${FLL_IMAGE_FILE%%.*}.${FLL_BUILD_ARCH[${arch}]}"
		FLL_IMAGE_LOCATION="${FLL_IMAGE_DIR}/${FLL_IMAGE_FILE}"

		#################################################################
		#		arch specific build area			#
		#################################################################
		FLL_BUILD_CHROOT="${FLL_BUILD_TEMP}/CHROOT-${FLL_BUILD_ARCH[${arch}]}"
		mkdir -vp "${FLL_BUILD_CHROOT}"

		if [[ ! -d ${FLL_BUILD_ISO_DIR} ]]; then
			if [[ ${FLL_BUILD_ISO_DIR} ]]; then
				echo "${SELF}: ${FLL_BUILD_ISO_DIR} does not exist!"
				echo "${SELF}: creating iso in ${FLL_BUILD_AREA}"
			fi
			FLL_BUILD_ISO_DIR="${FLL_BUILD_AREA}"
		fi

		#################################################################
		#		process package array(s)			#
		#################################################################
		unset FLL_PACKAGES
		if [[ ! -s "${FLL_BUILD_PACKAGE_PROFDIR}/${FLL_BUILD_PACKAGE_PROFILE}.bm" ]]; then
			echo "Unable to process package profile: ${FLL_BUILD_PACKAGE_PROFILE}"
			exit 5
		fi

		header "Processing: ${FLL_BUILD_PACKAGE_PROFDIR}/${FLL_BUILD_PACKAGE_PROFILE}.bm"
		source "${FLL_BUILD_PACKAGE_PROFDIR}/${FLL_BUILD_PACKAGE_PROFILE}.bm"

		for pkgmod in ${FLL_PACKAGE_DEPMODS[@]}; do
			header "Processing: ${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/${pkgmod}.bm"
			source "${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/${pkgmod}.bm"
		done

		header "Processing: ${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/early.bm"
		source "${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/early.bm"
		
		if [[ ! ${FLL_PACKAGES[@]} ]]; then
			echo "${SELF}: package profile did not produce FLL_PACKAGES array!"
			exit 6
		fi
		
		header "Package to be installed..."
		echo "${FLL_PACKAGES[@]}"

		#################################################################
		#		check kernel version				#
		#################################################################
		if [[ ${FLL_BUILD_LINUX_KERNEL[${arch}]} =~ '^[0-9]+\.[0-9]+(\.[0-9]+)?(\.?[0-9]*-.*)?' ]]; then
			KVERS="${FLL_BUILD_LINUX_KERNEL[${arch}]}"
		else
			if [[ ${FLL_BUILD_LINUX_KERNEL[${arch}]} ]]; then
				echo "Unrecognised kernel package: ${FLL_BUILD_LINUX_KERNEL[${arch}]}"
			else
				echo "Must define FLL_BUILD_LINUX_KERNEL in your conf"
			fi
			exit 6
		fi

		#################################################################
		#		create & prepare chroot				#
		#################################################################
		if [[ ${DEBUG} ]]; then
			FLL_DEBOOSTRAP_VERBOSITY="--debug"
		else
			FLL_DEBOOSTRAP_VERBOSITY="--verbose"
		fi

		header "running cdebootstrap..."
		cdebootstrap ${FLL_DEBOOSTRAP_VERBOSITY} --arch="${FLL_BUILD_ARCH[${arch}]}" --flavour=minimal "${FLL_BUILD_DEBIANMIRROR_SUITE}" \
			"${FLL_BUILD_CHROOT}" "${FLL_BUILD_DEBIANMIRROR_CACHED:=${FLL_BUILD_DEBIANMIRROR}}"
		
		chroot_virtfs mount

		cat_file_to_chroot chroot_policy	/usr/sbin/policy-rc.d
		cat_file_to_chroot debian_chroot	/etc/debian_chroot
		cat_file_to_chroot fstab		/etc/fstab
		cat_file_to_chroot interfaces		/etc/network/interfaces
		cat_file_to_chroot apt_sources_tmp	/etc/apt/sources.list
		
		chroot_exec apt-get update
		
		# import key for extra mirror(s)
		for i in ${!FLL_BUILD_EXTRAMIRROR[@]}; do
			header "Importing GPG key for ${FLL_BUILD_EXTRAMIRROR[${i}]}"
			if [[ -f ${FLL_BUILD_EXTRAMIRROR_GPGKEYID[${i}]} ]]; then
				cat ${FLL_BUILD_EXTRAMIRROR_GPGKEYID[${i}]} | chroot_exec apt-key add -
			elif [[ ${FLL_BUILD_EXTRAMIRROR_GPGKEYID[${i}]} ]]; then
				chroot_exec gpg --keyserver wwwkeys.eu.pgp.net --recv-keys \
					"${FLL_BUILD_EXTRAMIRROR_GPGKEYID[${i}]}" || :
			fi
		done

		# add imported gpg keys to apt's trusted keyring
		if exists_in_chroot /root/.gnupg/pubring.gpg; then
			header "Importing /root/.gnupg/pubring.gpg with apt-key..."
			chroot_exec apt-key add /root/.gnupg/pubring.gpg
		fi

		# refresh lists now that "secure apt" is aware of required gpg keys
		chroot_exec apt-get update
		
		# grab any fixes from fix.main
		chroot_exec apt-get --assume-yes dist-upgrade

		#################################################################
		#		install packages required early in chroot
		#################################################################
		chroot_exec apt-get --assume-yes install ${FLL_PACKAGES_EARLY[@]}

		# allow the user config to override distro-defaults
		sed -i	-e "s%\(FLL_DISTRO_NAME=\).*%\1\"${FLL_DISTRO_NAME}\"%" \
			-e "s%\(FLL_IMAGE_DIR=\).*%\1\"${FLL_IMAGE_DIR}\"%" \
			-e "s%\(FLL_IMAGE_FILE=\).*%\1\"${FLL_IMAGE_FILE}\"%" \
			-e "s%\(FLL_MOUNTPOINT=\).*%\1\"${FLL_MOUNTPOINT}\"%" \
			-e "s%\(FLL_MEDIA_NAME=\).*%\1\"${FLL_MEDIA_NAME}\"%" \
			-e "s%\(FLL_LIVE_USER=\).*%\1\"${FLL_LIVE_USER}\"%" \
			-e "s%\(FLL_LIVE_USER_GROUPS=\).*%\1\"${FLL_LIVE_USER_GROUPS}\"%" \
			-e "s%\(FLL_WALLPAPER=\).*%\1\"${FLL_WALLPAPER}\"%" \
			-e "s%\(FLL_IRC_SERVER=\).*%\1\"${FLL_IRC_SERVER}\"%" \
			-e "s%\(FLL_IRC_PORT=\).*%\1\"${FLL_IRC_PORT}\"%" \
			-e "s%\(FLL_IRC_CHANNEL=\).*%\1\"${FLL_IRC_CHANNEL}\"%" \
			-e "s%\(FLL_CDROM_INDEX=\).*%\1\"${FLL_CDROM_INDEX}\"%" \
			-e "s%\(FLL_CDROM_INDEX_ICON=\).*%\1\"${FLL_CDROM_INDEX_ICON}\"%" \
				"${FLL_BUILD_CHROOT}/etc/default/distro"
		
		#################################################################
		#		preseed locales					#
		#################################################################
		header "Configuring locales..."
		echo "locales	locales/default_environment_locale	select	en_US.UTF-8" | \
			chroot_exec debconf-set-selections
		
		echo "locales	locales/locales_to_be_generated	multiselect	be_BY.UTF-8 UTF-8, bg_BG.UTF-8 UTF-8, cs_CZ.UTF-8 UTF-8, da_DK.UTF-8 UTF-8, de_CH.UTF-8 UTF-8, de_DE.UTF-8 UTF-8, el_GR.UTF-8 UTF-8, en_AU.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, en_IE.UTF-8 UTF-8, en_US.UTF-8 UTF-8, es_ES.UTF-8 UTF-8, fi_FI.UTF-8 UTF-8, fr_FR.UTF-8 UTF-8, fr_BE.UTF-8 UTF-8, ga_IE.UTF-8 UTF-8, he_IL.UTF-8 UTF-8, hr_HR.UTF-8 UTF-8, hu_HU.UTF-8 UTF-8, it_IT.UTF-8 UTF-8, ja_JP.UTF-8 UTF-8, ko_KR.UTF-8 UTF-8, nb_NO.UTF-8 UTF-8, nl_NL.UTF-8 UTF-8, nl_BE.UTF-8 UTF-8, nn_NO.UTF-8 UTF-8, pl_PL.UTF-8 UTF-8, pt_BR.UTF-8 UTF-8, pt_PT.UTF-8 UTF-8, ro_RO.UTF-8 UTF-8, ru_RU.UTF-8 UTF-8, sk_SK.UTF-8 UTF-8, sl_SI.UTF-8 UTF-8, tr_TR.UTF-8 UTF-8, zh_CN.UTF-8 UTF-8, zh_TW.UTF-8 UTF-8" | \
			chroot_exec debconf-set-selections
		
		chroot_exec apt-get --assume-yes install locales

		#################################################################
		#		install kernel, make initial ramdisk		#
		#################################################################
		# module-init-tools required for depmod, it may not be in minimal bootstrap
		chroot_exec apt-get --assume-yes install fll-live-initramfs module-init-tools lvm2

		# ensure initrd is created by linux-image postinst hook
		cat_file_to_chroot kernel_img_conf /etc/kernel-img.conf
		
		KMODS=( $(grep-aptavail --no-field-names --show-field=Package --field=Package \
				  --eregex ".+-modules-${KVERS}$" \
				  "${FLL_BUILD_CHROOT}"/var/lib/apt/lists/*_Packages 2>/dev/null) )
		chroot_exec apt-get --assume-yes install linux-image-${KVERS} linux-headers-${KVERS} ${KMODS[@]}
		
		# grep for available kernel modules
		for dir in "${FLL_BUILD_CHROOT}"/lib/modules/*; do
			[[ -d ${dir} ]] || {
				echo "E: error detecting installed linux-image"
				exit 1
			}

			# substitute KVERS with actual version string
			KVERS=$(basename ${dir})
			
			chroot_exec update-initramfs -d -k ${KVERS}
			chroot_exec update-initramfs -v -c -k ${KVERS}
			mv -v "${FLL_BUILD_CHROOT}/boot/initrd.img-${KVERS}" "${FLL_BUILD_RESULT}/boot/"
			cp -v "${FLL_BUILD_CHROOT}/boot/vmlinuz-${KVERS}" "${FLL_BUILD_RESULT}/boot/"
			break
		done

		#################################################################
		#		mass package installation			#
		#################################################################
		header "Installing packages..."
		chroot_exec apt-get --assume-yes install ${FLL_PACKAGES[@]}

		# handle locale support packages
		header "processing locale support packages for: ${FLL_I18N_SUPPORT}"
		unset FLL_I18N_SUPPORT_PACKAGES
		if [[ ${FLL_I18N_SUPPORT} ]]; then
			FLL_I18N_SUPPORT="$(tr [:upper:] [:lower:] <<< ${FLL_I18N_SUPPORT})"
			FLL_I18N_SUPPORT_PACKAGES=( $(detect_i18n_support_packages ${FLL_I18N_SUPPORT}) )
			
			if [[ ${FLL_I18N_SUPPORT_PACKAGES[@]} ]]; then
				chroot_exec apt-get --assume-yes install ${FLL_I18N_SUPPORT_PACKAGES[@]}
			fi
		fi

		# handle recommends for specified packages
		header "Processing: ${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/recommends.bm"
		source "${FLL_BUILD_PACKAGE_PROFDIR}/packages.d/recommends.bm"

		if [[ ${FLL_PACKAGES_RECOMMENDS[@]} ]]; then
			if [[ ! -x $(which grep-dctrl) ]]; then
				echo "${SELF}: grep-dctrl missing!" 1>&2 
				exit 9
			fi
			
			header "Installing recommended packages for ${FLL_PACKAGES_RECOMMENDS[@]}"
			FLL_PACKAGES_EXTRA=( $(grep_recommends ${FLL_PACKAGES_RECOMMENDS[@]}) )

			if [[ ${FLL_PACKAGES_EXTRA[@]} ]]; then
				chroot_exec apt-get --assume-yes install ${FLL_PACKAGES_EXTRA[@]}
			fi
		fi
		
		#################################################################
		# 		init blacklist generation			#
		#################################################################
		if exists_in_chroot /usr/bin/fll_analyze_initscripts; then
			header "Creating initscript blacklist..."
		
			FLL_BUILD_INIT_BLACKLIST=$(mktemp -p ${FLL_BUILD_CHROOT} fll.blacklist.XXXX)
			FLL_BUILD_INIT_WHITELIST=$(mktemp -p ${FLL_BUILD_CHROOT} fll.whitelist.XXXX)
		
			cat "${FLL_BUILD_SHARED}/fll_init_blacklist" > "${FLL_BUILD_INIT_BLACKLIST}"
			cat "${FLL_BUILD_SHARED}/fll_init_whitelist" > "${FLL_BUILD_INIT_WHITELIST}"

			chroot_exec /usr/bin/fll_analyze_initscripts --remove \
				--blacklist "/${FLL_BUILD_INIT_BLACKLIST##*/}" \
				--whitelist "/${FLL_BUILD_INIT_WHITELIST##*/}" \
				| tee --append "${FLL_BUILD_CHROOT}/etc/default/fll-init"

			rm -fv "${FLL_BUILD_INIT_BLACKLIST}" "${FLL_BUILD_INIT_WHITELIST}"
		fi
		
		#################################################################
		#		hack inittab and shadow				#
		#################################################################
		# init 5 by default
		header "Hacking inittab..."
		sed -i  -e 's#^id:[0-6]:initdefault:#id:5:initdefault:#' \
			"${FLL_BUILD_CHROOT}"/etc/inittab

		if [[ -z ${FLL_ROOT_PASSWD} ]]; then
			# immutable bash login shells
			sed -i  -e 's#^\(~~:S:wait\):.\+#\1:/sbin/getty \-n \-i \-l /usr/bin/fll_login 38400 tty1#' \
				-e 's#^\(1\):\([0-9]\+\):\(respawn\):.\+#\1:\2:\3:/sbin/getty \-n \-i \-l /usr/bin/fll_login 38400 tty\1#' \
				-e 's#^\([2-6]\):\([0-9]\+\):\(respawn\):.\+#\1:\245:\3:/sbin/getty \-n \-i \-l /usr/bin/fll_login 38400 tty\1#' \
					"${FLL_BUILD_CHROOT}/etc/inittab"

			# lock down root
			sed -i "s#^\(root\):.*:\(.*:.*:.*:.*:.*:.*:.*\)#\1:\*:\2#" \
				"${FLL_BUILD_CHROOT}/etc/shadow"
		else
			# ${FLL_ROOT_PASSWD} must be an md5 hashed password - create with `openssl passwd -1'
			sed -i "s#^\(root\):.*:\(.*:.*:.*:.*:.*:.*:.*\)#\1:${FLL_ROOT_PASSWD}:\2#" \
				"${FLL_BUILD_CHROOT}/etc/shadow"
		fi

		if [ -w "${FLL_BUILD_CHROOT}/etc/pam.d/login" ]; then
			header 'Disabling pam_lastlog...'
			sed -i '/^[^#].*pam_lastlog\.so/s/^/# /' "${FLL_BUILD_CHROOT}/etc/pam.d/login"
		fi

		# Fix Debian kppp noauth defaults
		if [ -w "${FLL_BUILD_CHROOT}/etc/ppp/peers/kppp-options" ]; then
			header 'Allowing KPPP noauth...'
			sed -i 's/^#noauth/noauth/' "${FLL_BUILD_CHROOT}/etc/ppp/peers/kppp-options"
		fi
		#################################################################
		#		misc chroot debconf preseeding			#
		#################################################################
		# preconfigure fontconfig-config
		if installed_in_chroot fontconfig-config; then
			header "Fixing fontconfig"
			# hinting select Native|Autohinter|None
			echo "fontconfig-config fontconfig/hinting_type select Native" | chroot_exec debconf-set-selections
			# subpixel select Automatic|Always|Never
			echo "fontconfig-config fontconfig/subpixel_rendering select Automatic" | chroot_exec debconf-set-selections
			# bitmaps boolean true|false
			echo "fontconfig-config fontconfig/enable_bitmaps boolean false" | chroot_exec debconf-set-selections
		
			# disable bitmap fonts. create the symlink ourselves, derived from fontconfig-config.postinst
			if exists_in_chroot /etc/fonts/conf.avail/70-no-bitmaps.conf; then
				chroot_exec ln -vs /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/70-no-bitmaps.conf
			fi

			chroot_exec dpkg-reconfigure fontconfig
		fi

		# initialise debian menu system for fluxbox and friends
		if installed_in_chroot menu; then
			header "initialise debian menu system"
			chroot_exec update-menus
			wait
		fi

		# disable system-wide readable home directories
		if installed_in_chroot adduser; then
			header "Configuring adduser..."
			echo "adduser	adduser/homedir-permission	boolean	false" | chroot_exec debconf-set-selections
			# adduser.conf supersedes debconf preseeding...
			sed -i "s/^\(DIR_MODE\=\)[0-9]*$/\10751/" "${FLL_BUILD_CHROOT}/etc/adduser.conf"
		fi
		chmod 0751 "${FLL_BUILD_CHROOT}/root"

		if [[ ${#FLL_BUILD_ARCH[@]} -gt 1 ]]; then
			FLL_BUILD_MANIFEST="${FLL_BUILD_ISO_DIR}"/"${FLL_ISO_NAME}.${FLL_BUILD_ARCH[${arch}]}.manifest"
			FLL_BUILD_SOURCES="${FLL_BUILD_ISO_DIR}"/"${FLL_ISO_NAME}.${FLL_BUILD_ARCH[${arch}]}.sources"
		else
			FLL_BUILD_MANIFEST="${FLL_BUILD_ISO_DIR}"/"${FLL_ISO_NAME}.manifest"
			FLL_BUILD_SOURCES="${FLL_BUILD_ISO_DIR}"/"${FLL_ISO_NAME}.sources"
		fi
		
		# the formatting of this output is not "fancy" but it will suffice for now
		grep-dctrl --no-field-names --show-field=Package,Version --field=Status 'install ok installed' \
			"${FLL_BUILD_CHROOT}"/var/lib/dpkg/status | paste -sd "  \n" | sort -n > "${FLL_BUILD_MANIFEST}"
		
		if [[ ${FLL_SOURCE_RELEASE} -ge 1 ]]; then
			header "Creating source URI list manifest..."
			
			for p in $(cut -d' ' -f1 ${FLL_BUILD_MANIFEST}); do
				case "${p}" in
					*-modules-2\.[0-9].[0-9][0-9]*)
						p=${p//-modules-*/}
						case "${p}" in
							virtualbox-ose-guest)
								p=virtualbox-ose
								;;
						esac
						;;
				esac
				chroot_exec apt-get -qq --print-uris source ${p} | awk -F"'" '{ print $2 }'
			done | sort -u | tee --append "${FLL_BUILD_SOURCES}"
				
			# fix source URI's to use non cached address
			if [[ ${FLL_BUILD_DEBIANMIRROR_CACHED} && ${FLL_BUILD_DEBIANMIRROR} ]]; then
				sed -i 's#'"${FLL_BUILD_DEBIANMIRROR_CACHED}"'#'"${FLL_BUILD_DEBIANMIRROR}"'#' \
					"${FLL_BUILD_SOURCES}"
			fi

			for i in ${!FLL_BUILD_EXTRAMIRROR_CACHED[@]}; do
				[[ ${FLL_BUILD_EXTRAMIRROR_CACHED[${i}]} && ${FLL_BUILD_EXTRAMIRROR[${i}]} ]] || continue
				sed -i 's#'"${FLL_BUILD_EXTRAMIRROR_CACHED[${i}]}"'#'"${FLL_BUILD_EXTRAMIRROR[${i}]}"'#' \
					"${FLL_BUILD_SOURCES}"
			done
		fi

		#################################################################
		#		cleanup & prepare final chroot			#
		#################################################################
		header "Cleaning up..."
		chroot_exec dpkg --purge fll-live-initramfs cdebootstrap-helper-rc.d

		# remove used hacks and patches
		remove_from_chroot /etc/kernel-img.conf
		remove_from_chroot /usr/sbin/policy-rc.d
		remove_from_chroot /etc/debian_chroot
		remove_from_chroot /etc/hosts
		# nuke this one
		:> "${FLL_BUILD_CHROOT}"/etc/resolv.conf
		
		# create final config files
		cat_file_to_chroot hosts	/etc/hosts
		cat_file_to_chroot hostname	/etc/hostname
		cat_file_to_chroot apt_sources	/etc/apt/sources.list
		
		# add version marker
		if [ "${FLL_DISTRO_CODENAME}" = "snapshot" ]; then
			printf "${FLL_DISTRO_NAME} ${FLL_DISTRO_CODENAME} - ${FLL_BUILD_PACKAGE_PROFILE} - ($(date -u +%Y%m%d%H%M))\n" \
				>> "${FLL_BUILD_CHROOT}/etc/${FLL_DISTRO_NAME_LC}-version"
		else
			printf "${FLL_DISTRO_NAME} ${FLL_DISTRO_VERSION} - ${FLL_DISTRO_CODENAME} - ${FLL_BUILD_PACKAGE_PROFILE} - ($(date -u +%Y%m%d%H%M))\n" \
				>> "${FLL_BUILD_CHROOT}/etc/${FLL_DISTRO_NAME_LC}-version"
		fi
		chmod 0444 "${FLL_BUILD_CHROOT}/etc/${FLL_DISTRO_NAME_LC}-version"
		
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

		#################################################################
		#		prepare boot files				#
		#################################################################
		header "Preparing ISO /boot files..."

		# use menu.lst template file if it exists
		if [ -r "${FLL_BUILD_RESULT}/boot/grub/menu.lst.arch" ]; then
			if [[ "${FLL_BOOT_OPTIONS}" ]]; then
				FLL_BOOT_OPTIONS=" ${FLL_BOOT_OPTIONS}"
			fi
			sed	-e 's|@distro@|'"${FLL_DISTRO_NAME}"'|'	\
				-e 's|@arch@|'"${FLL_BUILD_ARCH[${arch}]}"'|'	\
				-e 's|@vmlinuz@|vmlinuz-'"${KVERS}"'|'  \
				-e 's|@initrd@|initrd\.img-'"${KVERS}"'|' \
				-e 's|^kernel.*|&'"${FLL_BOOT_OPTIONS}"'|' \
					"${FLL_BUILD_RESULT}/boot/grub/menu.lst.arch" >> \
						"${FLL_BUILD_RESULT}/boot/grub/menu.lst"

			sed	-e 's|@vmlinuz@|vmlinuz-'"${KVERS}"'|'	\
				-e 's|@initrd@|initrd\.img-'"${KVERS}"'|'	\
				-e 's|^kernel.*|&'"${FLL_BOOT_OPTIONS}"'|' \
					"${FLL_BUILD_RESULT}/boot/grub/menu.lst.in" > \
						"${FLL_BUILD_RESULT}/boot/grub/menu.lst.${FLL_BUILD_ARCH[${arch}]}"
		else	
			#sensible defaults
			echo >> "${FLL_BUILD_RESULT}/boot/grub/menu.lst"
	
			echo "title  ${FLL_DISTRO_NAME} ${FLL_BUILD_ARCH[${arch}]}" >> \
				"${FLL_BUILD_RESULT}/boot/grub/menu.lst"
			echo "kernel /boot/vmlinuz-${KVERS} boot=fll quiet vga=791 ${FLL_BOOT_OPTIONS}" >> \
				"${FLL_BUILD_RESULT}/boot/grub/menu.lst"
			echo "initrd /boot/initrd.img-${KVERS}" >> \
				"${FLL_BUILD_RESULT}/boot/grub/menu.lst"
		fi

		if exists_in_chroot /boot/message; then
			if [[ ! -f "${FLL_BUILD_RESULT}/boot/message" ]]; then
				cp -v "${FLL_BUILD_CHROOT}/boot/message.live" "${FLL_BUILD_RESULT}/boot/message"
			fi
		fi

		for f in "${FLL_BUILD_CHROOT}/usr/lib/grub"/*-pc/{iso9660_stage1_5,stage2_eltorito,stage2}; do
			if [[ ! -f "${FLL_BUILD_RESULT}/boot/grub/${f##*/}" ]]; then
				cp -v "${f}" "${FLL_BUILD_RESULT}/boot/grub/"
			fi
		done

		if exists_in_chroot /boot/memtest86+.bin; then
			if [[ ! -f "${FLL_BUILD_RESULT}/boot/memtest86+.bin" ]]; then
			 	cp -v "${FLL_BUILD_CHROOT}/boot/memtest86+.bin" "${FLL_BUILD_RESULT}/boot/"
			fi
		fi

		[[ ${FLL_BUILD_CHROOT_ONLY} ]] && continue

		#################################################################
		#		build						#
		#################################################################

		FLL_BUILD_EXCLUDEFILE=$(mktemp -p ${FLL_BUILD_TEMP} fll.exclude-file.XXXXX)
		FLL_BUILD_TMPEXCLUSION_LIST=$(mktemp -p ${FLL_BUILD_TEMP} fll.exclusions.XXXXX)
		FLL_BUILD_MKSQUASHFSOPTS=( "-ef ${FLL_BUILD_EXCLUDEFILE}" )

		if [[ ${FLL_BUILD_SQUASHFS_COMPRESSION} = "lzma" ]]; then
			FLL_BUILD_MKSQUASHFSOPTS+=( "-lzma" )
		fi

		header "Creating squashfs exclusions file..."
		cat "${FLL_BUILD_EXCLUSION_LIST}" > "${FLL_BUILD_TMPEXCLUSION_LIST}"
		pushd "${FLL_BUILD_CHROOT}" >/dev/null
			make_exclude_file "${FLL_BUILD_TMPEXCLUSION_LIST}" | tee "${FLL_BUILD_EXCLUDEFILE}"
		popd >/dev/null
		
		if [[ -s ${FLL_BUILD_SQUASHFS_SORTFILE} ]]; then
			FLL_BUILD_MKSQUASHFSOPTS+=( "-sort ${FLL_BUILD_SQUASHFS_SORTFILE}" )
		fi

		header "Creating squashfs..."
		pushd "${FLL_BUILD_CHROOT}" >/dev/null
			mksquashfs . "${FLL_BUILD_RESULT}/${FLL_IMAGE_LOCATION}" ${FLL_BUILD_MKSQUASHFSOPTS[@]}
		popd >/dev/null

		header "Nuking ${FLL_BUILD_CHROOT}..."
		nuke "${FLL_BUILD_CHROOT}"
	done

	[[ ${FLL_BUILD_CHROOT_ONLY} ]] && exit 0

	#################################################################
	#		prepare iso					#
	#################################################################
	if [ -f "${FLL_BUILD_RESULT}/boot/memtest86+.bin" ]; then
		echo 					>> "${FLL_BUILD_RESULT}/boot/grub/menu.lst"
		echo "title memtest86+" 		>> "${FLL_BUILD_RESULT}/boot/grub/menu.lst"
		echo "kernel /boot/memtest86+.bin" 	>> "${FLL_BUILD_RESULT}/boot/grub/menu.lst"
	fi
	rm -f "${FLL_BUILD_RESULT}/boot/grub/menu.lst.in"

	# md5sums
	header "Calculating md5sums..."
	pushd "${FLL_BUILD_RESULT}" >/dev/null
		find .	\
			-type f \
			-not \( \
				   -name '*md5sums' \
				-o -name '*.cat' \
				-o -name 'iso9660_stage1_5' \
				-o -name 'stage2_eltorito' \
			\) \
			-printf '%P\n' | xargs md5sum -b | sort -k 2 --ignore-case --output=md5sums
	popd >/dev/null

	# create iso sortlist
	FLL_BUILD_ISOSORTLIST=$(mktemp -p ${FLL_BUILD_TEMP} fll.isosortlist.XXXXX)

	cat > "${FLL_BUILD_ISOSORTLIST}" \
<<EOF
${FLL_BUILD_RESULT}/boot/grub/* 111111
${FLL_BUILD_RESULT}/boot/* 111110
${FLL_BUILD_RESULT}/${FLL_IMAGE_DIR} 100001
EOF

	# make the iso
	header "Creating ISO..."
	genisoimage -v -pad -l -r -J \
		-V "${FLL_DISTRO_NAME_UC}" \
		-A "${FLL_DISTRO_NAME_UC} LIVE LINUX CD" \
		-no-emul-boot -boot-load-size 4 -boot-info-table -hide-rr-moved \
		-b boot/grub/iso9660_stage1_5 -c boot/grub/boot.cat \
		-sort "${FLL_BUILD_ISOSORTLIST}" \
		-o "${FLL_BUILD_ISO_DIR}/${FLL_ISO_NAME}" \
		"${FLL_BUILD_RESULT}"

	# generate md5sums
	echo "Calculate md5sums for the resulting ISO..."
	pushd "${FLL_BUILD_ISO_DIR}" >/dev/null
		md5sum -b "${FLL_ISO_NAME}" | tee "${FLL_ISO_NAME}.md5"
	popd >/dev/null

	# if started as user, apply user ownership to output (based on --uid)
	if ((FLL_BUILD_OUTPUT_UID)); then
		chmod 0644 "${FLL_BUILD_ISO_DIR}/${FLL_ISO_NAME}"*
		chown "${FLL_BUILD_OUTPUT_UID}:${FLL_BUILD_OUTPUT_UID}" \
			"${FLL_BUILD_ISO_DIR}/${FLL_ISO_NAME}"*
	fi

	header "Nuking build area..."
	nuke_buildarea

	echo
	echo "${FLL_BUILD_ISO_DIR}/${FLL_ISO_NAME}"
done

exit 0
