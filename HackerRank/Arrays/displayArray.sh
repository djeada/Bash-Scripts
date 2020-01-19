#!/bin/bash
array=($(cat))
echo ${array[@]:3:1}
