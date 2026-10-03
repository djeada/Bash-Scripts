#!/usr/bin/env bash

# Script Name: smoke_test.sh
# Description: Lightweight tests for the scripts in src/. Every script is checked
#              for a shebang, the executable bit and valid bash syntax; scripts
#              that are pure (no network, root or interactive input) are also run
#              against known inputs and their output is compared.
# Usage: ./tests/smoke_test.sh

set -uo pipefail

export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$repo_root/src"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

pass() {
    passed=$((passed + 1))
}

fail() {
    failed=$((failed + 1))
    echo "FAIL: $*" >&2
}

# expect_output <description> <expected stdout> <command...>
expect_output() {
    local desc="$1" expected="$2" actual
    shift 2
    actual="$("$@" 2>/dev/null)"
    if [[ $actual == "$expected" ]]; then
        pass
    else
        fail "$desc"$'\n'"  expected: $(printf '%q' "$expected")"$'\n'"  actual:   $(printf '%q' "$actual")"
    fi
}

# expect_status <description> <expected exit code> <command...>
expect_status() {
    local desc="$1" expected="$2" actual
    shift 2
    "$@" >/dev/null 2>&1
    actual=$?
    if [[ $actual -eq $expected ]]; then
        pass
    else
        fail "$desc (expected exit $expected, got $actual)"
    fi
}

check_structure() {
    local script
    for script in "$src"/*.sh; do
        local name="${script#"$repo_root"/}"
        if [[ $(head -n1 "$script") == "#!/usr/bin/env bash" ]]; then pass; else fail "$name: missing '#!/usr/bin/env bash' shebang"; fi
        if [[ -x $script ]]; then pass; else fail "$name: not executable"; fi
        if bash -n "$script" 2>/dev/null; then pass; else fail "$name: syntax error"; fi
    done
}

test_new_utilities() {
    # retry.sh
    expect_status "retry: succeeds immediately" 0 "$src/retry.sh" true
    expect_status "retry: propagates last exit code" 3 "$src/retry.sh" -n 2 -d 0 -q -- bash -c 'exit 3'
    local counter="$work/counter"
    expect_status "retry: succeeds on third attempt" 0 "$src/retry.sh" -n 5 -d 0 -q -- bash -c "echo x >>'$counter'; [ \$(wc -l <'$counter') -ge 3 ]"
    expect_status "retry: rejects bad attempts" 2 "$src/retry.sh" -n x -- true

    # wait_for_port.sh
    expect_status "wait_for_port: times out on closed port" 1 "$src/wait_for_port.sh" -q -t 1 127.0.0.1:1
    expect_status "wait_for_port: rejects malformed target" 2 "$src/wait_for_port.sh" localhost
    expect_status "wait_for_port: rejects invalid port" 2 "$src/wait_for_port.sh" localhost:70000

    # find_duplicate_files.sh
    mkdir -p "$work/dups/sub dir" "$work/dups/.hidden"
    echo same >"$work/dups/a.txt"
    echo same >"$work/dups/sub dir/b c.txt"
    echo same >"$work/dups/.hidden/d.txt"
    echo diff >"$work/dups/e.txt"
    expect_output "find_duplicate_files: finds group" \
        "$work/dups/a.txt"$'\n'"$work/dups/sub dir/b c.txt"$'\n\n'"Found 1 group(s) of duplicates; 5B could be reclaimed." \
        "$src/find_duplicate_files.sh" "$work/dups"
    expect_output "find_duplicate_files: no duplicates" "No duplicate files found." \
        "$src/find_duplicate_files.sh" "$work/dups/sub dir"

    # find_large_files.sh
    head -c 2048 /dev/zero >"$work/dups/big.bin"
    expect_output "find_large_files: largest first" "   2.0KB	$work/dups/big.bin" \
        "$src/find_large_files.sh" -n 1 "$work/dups"
}

test_math_and_strings() {
    expect_output "factorial: 5" "The factorial of 5 is: 120" "$src/factorial.sh" 5
    expect_output "factorial: 0" "The factorial of 0 is: 1" "$src/factorial.sh" 0
    expect_output "is_prime: 7" "7 is a prime number!" "$src/is_prime.sh" 7
    expect_output "is_prime: leading zero is decimal" "8 is not a prime number!" "$src/is_prime.sh" 08
    expect_output "decimal_binary: d2b" "Conversion of decimal number 10 to binary:"$'\n'"1010" "$src/decimal_binary.sh" -d2b 10
    expect_output "decimal_binary: b2d" "Conversion of binary number 1010 to decimal:"$'\n'"10" "$src/decimal_binary.sh" -b2d 1010
    expect_output "sum_args" "Arguments submitted:"$'\n'"1"$'\n'"2"$'\n'"08"$'\n'"Sum of the arguments: 11" "$src/sum_args.sh" 1 2 08
    expect_output "sum_smaller_numbers" "The sum of integers smaller than 5 is 10." "$src/sum_smaller_numbers.sh" 5
    expect_output "sqrt: rounds" "2.83" "$src/sqrt.sh" 8 2
    expect_output "sqrt: zero" "0" "$src/sqrt.sh" 0
    expect_output "arith_mean" "Arithmetic mean of 1 2 3 4 is 2.50" "$src/arith_mean.sh" 1 2 3 4
    expect_output "max_array: negatives" "7" "$src/max_array.sh" 3 -1 7
    expect_output "min_array: negatives" "-1" "$src/min_array.sh" 3 -1 7
    expect_output "numbers_in_interval" "3"$'\n'"4"$'\n'"5" "$src/numbers_in_interval.sh" 3 5
    expect_output "remove_duplicates_in_array: keeps order" "b a c" "$src/remove_duplicates_in_array.sh" b a b c
    expect_output "hamming_distance" 'The Hamming Distance between "abc" and "abd" is: 1' "$src/hamming_distance.sh" abc abd
    expect_status "hamming_distance: unequal lengths" 2 "$src/hamming_distance.sh" abc ab
    expect_status "are_anagrams: yes" 0 "$src/are_anagrams.sh" listen silent
    expect_status "are_anagrams: no" 1 "$src/are_anagrams.sh" abc abd
    expect_output "count_char: spaces" "2" "$src/count_char.sh" "a b c" " "
    expect_output "upper" "HELLO" "$src/upper.sh" hello
    expect_output "lower" "hello" "$src/lower.sh" HeLLo
    expect_output "is_palindrome" "true" "$src/is_palindrome.sh" racecar
    expect_output "sort_string" "abcd" "$src/sort_string.sh" dcba
    expect_output "month_to_number: full name" "3" "$src/month_to_number.sh" March
    expect_output "month_to_number: short name" "1" "$src/month_to_number.sh" jan
    expect_output "month_to_number: number" "aug" "$src/month_to_number.sh" 08
}

test_file_utilities() {
    local f="$work/file.txt"

    printf 'a\nb\nc\n' >"$f"
    expect_output "middle_line" "b" "$src/middle_line.sh" "$f"

    echo "ab1c 22x" >"$f"
    "$src/strip_digits.sh" "$f" >/dev/null 2>&1
    expect_output "strip_digits: removes digits only" "abc x" cat "$f"

    printf 'x  \ny\t\n' >"$f"
    chmod 755 "$f"
    expect_status "remove_trailing_whitespaces: --check detects" 1 "$src/remove_trailing_whitespaces.sh" --check "$f"
    "$src/remove_trailing_whitespaces.sh" "$f" >/dev/null 2>&1
    expect_output "remove_trailing_whitespaces: fixes" "x"$'\n'"y" cat "$f"
    expect_output "remove_trailing_whitespaces: keeps mode" "755" stat -c %a "$f"

    printf 'x\r\n' >"$f"
    expect_status "remove_carriage_return: --check detects" 1 "$src/remove_carriage_return.sh" --check "$f"

    printf 'x\n' >"$f"
    expect_status "last_line_empty: --check detects" 1 "$src/last_line_empty.sh" --check "$f"
    "$src/last_line_empty.sh" "$f" >/dev/null 2>&1
    expect_output "last_line_empty: keeps mode" "755" stat -c %a "$f"
    expect_status "last_line_empty: fixed" 0 "$src/last_line_empty.sh" --check "$f"
}

check_structure
test_new_utilities
test_math_and_strings
test_file_utilities

echo "Passed: $passed, failed: $failed"
[[ $failed -eq 0 ]]

