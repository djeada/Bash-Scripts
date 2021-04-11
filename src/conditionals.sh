#!/bin/bash

read c

if [ "$c"  == "n" ] || [ "$c" == "N" ]; then
    echo NO
fi
if [ "$c"  == "y" ] || [ "$c" == "Y" ]; then
    echo YES
fi
