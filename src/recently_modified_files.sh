dir="$1"
n="$2"
find "$dir" -type f -printf '%TY-%Tm-%Td %TT %p\n' | sort -r | head -n "$n"
