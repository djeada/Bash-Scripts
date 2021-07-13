source="*.py"
funcs=$(cat $source | grep 'def' | sed 's/def //g' | sed 's/(.*/(/' | grep -v '#')
for f in $funcs
do
    echo $f $(expr $(cat $source | grep -c $f) - 1)
done
