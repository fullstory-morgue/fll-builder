#!/bin/bash
# (C) 2007 Florian Schneider <ffw_schneider@web.de>

version="0.11"
newMenue=
backup=0
directory=""
globalDir=`pwd`

showHelp (){
	echo "updateMenue version " $version
	echo usage:
	echo "./updateMenue -f <file> [-b | -d] | -r | -h"
	echo
	echo "This script removes the <div id=\"menue\"> ... <\\div> block from"
	echo "every *.htm file in given directory (-d) and replace that block with "
	echo "the content of a file (-f)"
	echo
	echo "-f, --file 	input file with new menue structure "
	echo "-d, --directory	working directory"
	echo "-b, --backup	creates a backup of every file before edit"
	echo "-r, --remove	removes all backup files in current directory"
	echo "			this option can only be used with -d as option BEFORE -r"
	echo "-h, --help 	display this help"
	exit 0
}

removeBackupFiles (){
	echo "Remove backup files:"
	for file in `ls -1 $directory`; do
		if [[ $file = *.htm.* ]]
		then
			echo "Delete " $file
			`rm -f ${directory}$file`
			echo "...done"
		fi
	done
	exit 0
}


date=`date +%Y%m%d`"_"`date +%H%M`
#newMenue=$(<$1)

replaceMenue (){
echo $directory " is used as working directory..."


for file in `ls -1 $directory`; do
	 
	#Just handle *.htm files
	if [[ $file = *.htm ]]
	then
		echo "Working on file: " ${directory}${file}: 
		#echo $directory
		startLine=0
		endLine=0
		maxLine=$(wc -l < "${directory}${file}")
		((maxLine++))

		n=1
		divCounter=0
		OIFS=$IFS; IFS=
		while read line
		do
			if [[ $line = *\<div\ id\=* ]]
			then
				if [[ $line = *\<div\ id\=\"menu\"\>* ]] 
				then
					startLine=$n
				else
					if [[ $line != *\<\/div\>* ]]
					then 
						((divCounter++))
					fi
				fi
				((n++))
			elif [[ $line = *\<\/div\>* ]]
			then
				if divCounter=0
				then
					endLine=$n
					break
				else
					((divCounter--))
					((n++))
				fi
			((n++))
			else
			((n++))
			fi
			
		done < ${directory}${file}
		#IFS=$OIFS

		echo Startline: $startLine
		echo Endline: $endLine
		echo maxLine: $maxLine
		part1=`sed -e "${startLine},${maxLine}d" ${directory}$file` 
		part2=`sed -e "1,${endLine}d" ${directory}$file`	
		
		if [[ $backup = 1 ]]
		then 
			#echo ${directory}$file
			`cp ${directory}$file ${directory}${file}".$date"`
		fi
	
		echo "${part1}" > ${directory}$file
		echo "${newMenue}" >> ${directory}$file
		echo "${part2}" >> ${directory}$file
		echo "...done"
	fi
done
}


while [ $# -gt 0 ]; do
        case "$1" in
		"-h"|"--help")
			showHelp;;
		
		"-f"|"--file")
			newMenue=$(<$2);;
		
		"-b"|"--backup")
		        echo "Backup active!"
			backup=1;;
		
		"-r"|"--remove")
			if [[ $# -gt 2 ]]
			then
				showHelp
			else
		        	removeBackupFiles
			fi;;
		
		"-d"|"--directory")
			sep=""
			if [[ $2 != /* ]] 
			then
				directory=$globalDir
				sep="/"	
			fi
			if [[ $2 = */ ]]
			then
				directory=${directory}${sep}$2
			else
				directory=${directory}${sep}$2"/"
			fi;;
	        esac
	        shift
done

if [[ $newMenue = "" ]]
then
	showHelp
fi

replaceMenue

