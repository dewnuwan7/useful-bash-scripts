#!/bin/bash

CURRENT_FILE_TYPE=$1
NEW_FILE_TYPE=$2

for file in *.$CURRENT_FILE_TYPE
do
  mv $file "${file%.$CURRENT_FILE_TYPE}.$NEW_FILE_TYPE"
  echo "Files renamed Succesfully!"
done



