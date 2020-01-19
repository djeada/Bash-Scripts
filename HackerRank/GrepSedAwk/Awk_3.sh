#!/bin/bash
awk '{s=$2+$3+$4; print $0 " : " (s>=240?"A":s>=180?"B":s>=150?"C":"FAIL")}'
