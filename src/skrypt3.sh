#!/bin/bash
FILE=$~/.xsession-errors     
if [ -f $FILE ]; then
   echo "File $FILE exists."
else
   echo "File $FILE does not exist."
fi

VAR1=$(ls / | wc -l)
VAR2=$(ls ~/ | wc -l)

echo "W katalogu gównym jest $VAR1 plików, 
a w katalogu domowym jest $VAR2 plików. "
