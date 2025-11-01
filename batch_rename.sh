#!/bin/bash

FILE_TYPE=$1
OPTION=$2
NAME_ADDITION=$3
COUNT=0

if [[ "$OPTION" != "-p" && "$OPTION" != "-s" ]]; then
    echo "Invalid Syntax/Argument!"
    echo ""
    echo "Example: ./batch_rename.sh txt -p name_prefix"
    echo "Example: ./batch_rename.sh txt -s name_suffix"
fi

for file in *.$FILE_TYPE;
do
  if [[ "$OPTION" == "-p" ]]; then
    mv $file "${NAME_ADDITION}_${file}"
    ((COUNT++))
    echo "$file -------------> ${NAME_ADDITION}_${file}"

  elif [[ "$OPTION" == "-s" ]]; then
    mv $file "${file%.$FILE_TYPE}_${NAME_ADDITION}.${FILE_TYPE}"
    ((COUNT++))
    echo "$file -------------> ${file%.$FILE_TYPE}_${NAME_ADDITION}.${FILE_TYPE}"
  fi 
done
  
echo ""
echo "$COUNT files renmaed successfully!"



