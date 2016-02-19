#!/bin/bash
# OCR.sh
# multithreaded OCR with tesseract 3.03, tested in Ubuntu 14.04
# pokes text as layer into PDF, works in memory (/run/shm/)
# needs pdftk, pdftoppm, tesseract
# Michael Luthardt <edv@dr-luthardt.de> 2013, 2015

# check for valid PDF as first argument
if (! [ $# -ge 1 ] || ! (gs -q -o nul -sDEVICE=nullpage -dFirstPage=1 -dLastPage=1 "$1" &>/dev/null)); then
	cat << eot
	First argument is not a valid PDF or doesn't exist.
	Usage: [path/to/]pdffile [lan] [-y]
		See tesseract --list-langs for installed languages.
eot
	exit 1
fi

# check for parameters
# language as 2nd argument, if not, set default (deu)
# it's your own task to provide lan.traineddata
# with option -y OCR is forced anyway

FORCE=0 # as a precaution
if [ ${#} -eq 1 ]; then
	LANG=deu
else
	[ ${#2} -eq 3 ] && LANG=$2 || LANG=deu
	[ "x$2" == "x-y" ] && FORCE=1
	[ "x$3" == "x-y" ] && FORCE=1
fi

if [ $FORCE -eq 0 ]; then
#check if PDF already contains a text layer
	unset -v ANS	# as a precaution
	if [ $(pdftotext "$1" - | grep -cE '[[:alpha:]]' 2>/dev/null) -ne 0 ]; then
		echo -e "\nThis PDF contains a text layer."
		read -r -p "Proceed anyway? Old text will be removed. [N|y] " ANS
		[ "x$ANS" = "xy" ] || { echo; exit 2; }
	fi
fi

FILE=`basename "$1"`

# find number of cpus, calculate maxjobs
NCPUS=$(lscpu | sed -n '/^CPU(s)/s/CPU(s): *//p')
MAXJOBS=$((($NCPUS+1)/2))

# work in memory:
cp "$1" /run/shm/
cd /run/shm
rm -f pg_* pg-* # as a precaution

# burst input PDF into pages
tput bold; echo -e "\n${FILE}:"; tput sgr0
pdftk "$FILE" burst
echo "`sed -n '/NumberOfPages/s/NumberOfPages: //p' doc_data.txt` pages to process ..."

# we don't need the input PDF and it's info doc any longer in memory
rm -f "$FILE" doc_data.txt

# bundle all actions into one function
export ERR=0
ocr() 
{
    pdftoppm -png -r 300 $PAGE ${PAGE%.*} &>/dev/null
    let ERR=$ERR+$?
    tesseract -l $LANG ${PAGE%.*}-1.png ${PAGE%.*} pdf &>/dev/null
    let ERR=$ERR+$?
    [ $ERR -eq 0 ] && { tput civis; echo -en "        ... $PAGE done\r"; tput cnorm; } \
    || { tput civis; echo -en "\n        ... $PAGE something went wrong\n"; tput cnorm; }
    rm -f ${PAGE%.*}-1.png 
}

# do orc() in background
for PAGE in pg_*.pdf; do
	ocr $PAGE &
	# but limit the number of simultaneous jobs
 	[ `jobs -p | wc -l` -ge $MAXJOBS ] && wait
 	[ $ERR -ne 0 ] && break
done

# wait for last bg job to finish – important!
wait

# leave memory
cd - &>/dev/null

# concatenate pdf's to input_ocr.pdf
if [ $ERR -eq 0 ]; then
	pdftk /run/shm/pg_*.pdf cat output "${1%.*}_ocr.pdf"
	[ $? -eq 0 ] && echo -e "\n\n\t... ${1%.*}_ocr.pdf created\n" \
	|| echo -e "\n\n\t... Error encountered.  No output created.\n"
else
	echo -e "\n\\t... Errors encountered.  No output created.\n"
fi

# clear memory
rm -f /run/shm/pg_*

exit