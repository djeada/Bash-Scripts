#!/bin/bash
array=($(cat))
echo ${array[@]/*[a|A]*/}
