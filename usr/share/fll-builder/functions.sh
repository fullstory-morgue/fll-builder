#!/bin/sh
# Common shell functions for fll-build(8)

print_copyright()
{
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

print_help()
{
cat <<EOF

Usage: $SELF [options]

Options:
  -c|--configfile	path to alternate configfile
  (default: /etc/fll-builder/fll-build.conf)

  -h|--help		information about using this program

  -v|--version		$SELF version and copyright information

EOF
}

print_version()
{
cat <<EOF

$SELF
Version: $VERSION

EOF
}