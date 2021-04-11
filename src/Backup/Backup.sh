#!/bin/bash

#read the variables from config file
. ~/.config/sk/back1.cfg

#store all the backup folders in one directory
mkdir backupDir

for i in "${arr[@]}"
do
	sudo cp -Rf $i backupDir
done

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

