#!/usr/bin/env bash
echo "Enter directory name"
read dirName
if [-d "$dirName" ]
then
    echo "Directory already exists!"
else
    `mkdir $dirName`
    echo "Directory has been created!"
fi
