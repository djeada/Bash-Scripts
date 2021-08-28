#!/usr/bin/env bash

confFile="backup_conf"

if [ ! -f "$confFile" ]; then
    echo "$confFile does not exist."
    echo "Edit the file and run the script again."
    echo 'declare -a arr=("/home/adam/Documents/temp")' > $confFile
    echo 'destFolder="."' >> $confFile
    echo 'maxSize="10M"' >> $confFile
    echo 'exclude=".sh"' >> $confFile
    exit 0
fi

#read the variables from the config file
. $confFile

#store all the backup folders in one directory
tempDir="temp$(date)"
echo $tempDir
mkdir -p $tempDir

for i in "${sourceFiles[@]}"
do
    cp -Rf $i $tempDir
done

#prepare the archive
day=$(date +%Y-%m-%d)
hostname=$(hostname -s)
archive="$hostname-$day.tar.gz"

#print start backup massage.
echo "Backing up $arr to $dest/$archive"
date

#Backup the files using tar
tar -zcvf $destFolder/$archive --exclude=$exclude --exclude-from <(find $tempDir -size +$maxSize) $tempDir

#print end status message
echo "Backup finished! $(date)"

#encryption
echo "Encrypting backup..."
gpg -c $destFolder/$archive
echo "Encryption finished!"

#remove unencrypted backup file
rm -rf $destFolder/$archive
rm -rf $tempDir

