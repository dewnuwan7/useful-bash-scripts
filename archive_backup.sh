#!/bin/bash

echo "Archive & Backup"
read -p "Copy Path: " PATH_TO_COPY
read -p "Backup Path: " PATH_TO_BACKUP

FILENAME=$(date | grep$)

#echo "$PATH_TO_COPY"
#echo "$PATH_TO_BACKUP"
cp -r $PATH_TO_COPY $PATH_TO_BACKUP
then
  tar xvf $date

echo ""
echo "Backup Completed!"
