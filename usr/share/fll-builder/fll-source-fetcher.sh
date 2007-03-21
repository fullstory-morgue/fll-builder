#!/bin/sh

mkdir -p source

[ -f list ] && rm -f list

# process args
for arg in ${@}; do
	case ${arg} in
		*.SOURCES)
			# concatenate url lists
			[ -s ${arg} ] && cat ${arg} >> list
			;;
		*)
			echo "fll-source-fetcher SOURCES1 SOURCES2 ..."
			exit 1
			;;
	esac
done

if [ ! -s list ]; then
	echo "E: no sources to download!"
	echo "fll-source-fetcher SOURCES1 SOURCES2 ..."
	exit 1
fi

# download source packages
for url in $(sort --unique list); do
	case ${url} in
		*.dsc|*.diff.gz|*.orig.tar.gz)
			file=$(basename ${url})
			wget -nv -Nc -O source/${file} ${url}
			# check we downloaded file
			if [ ! -f source/${file} ]; then
				echo "E: failed to fetch ${file}"
				exit 1
			fi
			;;
		*)
			;;
	esac
done

rm -f list

# sort source packages
for dsc in source/*.dsc; do
	[ -f ${dsc} ] || continue

	SOURCE=$(sed -n 's/^Source: //p' ${dsc})
	
	case ${SOURCE} in
		lib?*)
			LETTER=$(echo ${SOURCE} | sed 's/\(....\).*/\1/')
			;;
		*)
			LETTER=$(echo ${SOURCE} | sed 's/\(.\).*/\1/')
			;;
	esac
 
	mkdir -p source/${LETTER}/${SOURCE}
 	
	mv source/${SOURCE}_* source/${LETTER}/${SOURCE}
done

tar -cvf source.tar source
