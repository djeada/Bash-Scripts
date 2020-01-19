#!/bin/bash
array=($(cat))
echo ${array[@]/[:A-Z:]/.}
