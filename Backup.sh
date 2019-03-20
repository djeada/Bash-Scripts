#!/bin/bash

#what files or folders to tak backup of.
sourceFolder="/etc"

#destination of backup.
destFolder="/home/adam/Desktop"

#declaring max Size
maxSize="10M"

#excluding file extansions
exclusion="*.sh"

#create archive filename.
day=$(date +%Y-%m-%d)
hostname=$(hostname -s)
archive_file="$hostname-$day.tar.gz"

#print start backup massage.
echo "Backing up $sourceFolder to $dest/$archive_file"
date
echo

#Backup the files using tar.
tar -zcvf $destFolder/$archive_file --exclude=$exclusion --exclude-from <(find $sourceFolder -size +$maxSize) $sourceFolder
 
#print end status message
echo
echo "Backup finished"
date

#long listing the files in dest to check their sizes
ls -lh $dest

#encryption
gpg -c $destFolder/$archive_file

#remove unencrypted file
rm -r $destFolder/$archive_file


