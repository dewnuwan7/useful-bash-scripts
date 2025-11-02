#!/bin/bash

##example

#./touch_files.sh [file_size] [file] [amount_of_files]
#./touch_files.sh 10M note.txt 20

FILE=$2
AMOUNT=$3
SIZE=$1

BASE=${FILE%.*}
EXTENTION=${FILE##*.}

COUNT=0

while [[ "$COUNT" -le "$AMOUNT" ]];
do  
  NEWFILE="${BASE}_${COUNT}.${EXTENTION}"
  fallocate -l $SIZE $NEWFILE
  #touch "$NEWFILE"
  ((COUNT++))
done

echo "Created $AMOUNT of $FILE"


