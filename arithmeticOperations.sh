#!/bin/bash
read expression
echo "scale=5; $expression" | bc -l | awk '{printf "%.3f", $1}'
