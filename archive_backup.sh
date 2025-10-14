#!/bin/bash

echo "Archive & Backup"
echo ""

read -p "Copy Path: " PATH_TO_COPY
read -p "Backup Path: " PATH_TO_BACKUP

FILENAME=$(basename $PATH_TO_COPY)
DATE=$(date +%Y-%m-%d)
ZIPNAME="${DATE}_${FILENAME}"

#echo "$ZIPNAME"
echo ""

tar -czvf "$ZIPNAME.tar.gz" $FILENAME
mv "$ZIPNAME.tar.gz" $PATH_TO_BACKUP

echo ""
echo "Backup Completed!"
