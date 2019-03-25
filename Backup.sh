#!/bin/bash

#what files or folders to take backup of
declare -a arr=("/home/adam/Desktop" "/etc" "/home/adam/Desktop/Rogue")

#sourceFolder="/home/adam/Desktop"

#destination of backup
destFolder="/home/adam/Desktop"

#store all the backup folders in one directory
mkdir backupDir

for i in "${arr[@]}"
do
	sudo cp -Rf $i backupDir
done

#declaring max Size
maxSize="10M"

#excluding file extansions
exclusion="*.sh"

#create archive filename
day=$(date +%Y-%m-%d)
hostname=$(hostname -s)
archive_file="$hostname-$day.tar.gz"

#print start backup massage.
echo "Backing up $sourceFolder to $dest/$archive_file"
date
echo

#Backup the files using tar
tar -zcvf $destFolder/$archive_file --exclude=$exclusion --exclude-from <(find backupDir -size +$maxSize) backupDir

#print end status message
echo
echo "Backup finished"
date

#long listing the files in dest to check their sizes
ls -lh $dest

#encryption
gpg -c $destFolder/$archive_file

#remove unencrypted backup file
rm -r $destFolder/$archive_file

