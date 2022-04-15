echo "Processes which might be orphans:"
ps -ef | awk '$3 == 1 { print $0 }'
