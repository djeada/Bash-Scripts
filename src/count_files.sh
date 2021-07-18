#!/bin/bash
FILE=$~/.xsession-errors     
if [ -f $FILE ]; then
   echo "File $FILE exists."
else
   echo "File $FILE does not exist."
fi

VAR1=$(ls / | wc -l)
VAR2=$(ls ~/ | wc -l)

echo "In root dir there are $VAR1 files and in home dir there are $VAR2 files."
