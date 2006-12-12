#!/bin/sh
# Common shell functions for fll-build(8)

print_help()
{
cat <<EOF

Usage: $SELF [options]

Options:
  -c|--configfile	path to alternate configfile
  (default: /etc/fll-builder/fll-build.conf)

  -h|--help		information about using this program

  -v|--version		$SELF version

EOF
}

print_version()
{
cat <<EOF

$SELF
Version: $VERSION

EOF
}
