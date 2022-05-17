<div align="center">
<a href="https://github.com/djeada/Bash-scripts/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/network"><img alt="GitHub forks" src="https://img.shields.io/github/forks/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/blob/master/LICENSE"><img alt="GitHub license" src="https://img.shields.io/github/license/djeada/Bash-scripts"></a>
<a href=""><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat"></a>
</div>

# Bash-scripts
A collection of Bash scripts.

## About Bash

* Scripting languages originated as extensions of command interpreters in operating systems.
* Bourne shell (sh) was the first significant shell. Bash, today's most used Unix shell, is a GNU/FSF enhancement on the Bourne shell.
* Other shells include: C shell (csh), TC shell (tcsh), Dash (dash), Korn shell (ksh), Z shell (zsh).

###  What's the purpose of shell scripts? 

* When working on programming projects or doing administrative tasks on servers, usually several command sequences are regularly repeated. This is especially true when working with files and directories, processing text, or configuring the network. Numerous times, those command sequences exist in many forms and must be adjusted with user input, necessitating the usage of scripts.
* Scripting languages such as Bash improve our processes by including variables, if statements, loops, arrays, and functions, allowing for more sophisticated program flow.
* The actual power of shell script comes from all of the accessible Unix commands.
* Eventually, scripts get too complicated for basic languages such as Bash. At this stage, you should consider utilizing more powerful programming languages, such as Python.
* Shell scripts may also be used to "glue" together more complex Python scripts.

###  When should you not use Bash? 

* Complex applications.
* GUI.
* Cross-platform portability.
* Calculations.
* Network programming.


### Hello world 

This is a simple example of a Bash script. It prints the string "Hello World" to the standard output (stdout). 

```bash
#!/usr/bin/env bash
echo "Hello world"
```

### Executing a script 

To run this script, type the following command in a terminal in the directory where the script is located:

```bash
chmod u+x filename.sh
./filename.sh
```

### The shebang

In the first line of a script, the shebang (#!) is used to specify the interpreter to be used when the script is executed. To use the bash interpreter, the first line of a script file must specify the absolute path to the bash executable:

```bash
#!/usr/bin/env bash
```

The bash path in the shebang is resolved and utilized only when a script is launched directly from a terminal. If the script is launched from a shell script, the interpreter is not resolved and the script is executed using the shell interpreter.

```bash
./filename.sh
```

When a bash interpreter is explicitly specified to execute a script, the shebang is ignored:

```bash
bash ./filename.sh
```

Scripts may also be created in a variety of different "scripting languages," thus a Perl script might begin with <i>#!/usr/bin/env perl</i> and one in Python with <i> #!/usr/bin/env python3</i>.

### Variables 
  
* Assign the value: <i>var="Test"</i>.
* Retrive the value: <i>$x</i> or <i>${x}</i>.
* Variables can be defined explicitly as int or array:

```bash
declare -i var      # var is an int
declare -a arr      # arr in an array
declare -r var2=5   # var2 is read only
```

* Variables can store the value of executed command:

```bash
var=$(whoami)
```

### Command line arguments 

* First argument: <i>$1</i>
* All command line arguments as array: <i>$@</i>
* Number of command line arguments: <i>$#</i>
* The exit status of the last executed command: <i>$?</i>

### If statements 

If statements are used to execute a block of code if a certain condition is met. Comparison of strings and ints differs. Assume that all values are strings, unless proven otherwise.

```bash
if [ $i -eq 10 ]; then echo True; fi         # int comparison
if [ "$name" == "10" ]; then echo True; fi   # string comparison
```

Integer comparison:

| Operator | Description |
| --- | --- |
| <i>-eq</i> | equal |
| <i>-ne</i> | not equal |
| <i>-gt</i> | greater than |
| <i>-ge</i> | greater than or equal to |
| <i>-lt</i> | less than |
| <i>-le</i> | less than or equal to |

String comparison:

| Operator | Description |
| --- | --- |
| <i>==</i> | equal |
| <i>!=</i> | not equal |
| <i>></i> | greater than |
| <i><</i> | less than |
| <i>-n</i> | string is not null |
| <i>-z</i> | string is null |

Single [] are condition tests that are compatible with the posix shell.

Bash and other shells (e.g. zsh, ksh) allow double [[]] as an enhancement to the usual []. They expand the standard possix operations with other operations. For example, instead of -o, it is possible to use || and do regex matching with =~.

If you need to perform word splitting or filename expansion, you'd use single square brackets. Assuming there is just one csv file named 'file.csv' in the current directory, the following line of code will not print True:

```bash
if [[ -f *.csv ]]; then echo True; fi
```

The reason for this is that the test condition checks for a file with the name '\*.txt' and no globbing is performed. This line of code, on the other hand, will print True:

```bash
if [ -f *.csv ]; then echo True; fi
```

### For loops

A for loop repeats a sequence of steps a number of times.

```bash
for number in {1..10}
do
  echo "$number "
done
```

### Arrays

An array is a variable that holds an ordered list of values. The values are separated by spaces. The following example creates an array named <i>array</i> and assigns the values 1, 2, 3, 4, 5 to it:

```bash
array=(1 2 3 4 5) 
```

It is possible to create an array with specified element indices:

```bash
array=([3]='elem_a' [4]='elem_b')
```

To insert an elementat (e.g. 'abc') at a given index (e.g. 2) in the array, use the following syntax:

```bash
array=("${array[@]:0:2}" 'new' "${array[@]:2}")
```

To iterate over the elements of an array, use the following syntax:

```bash
items=('item_1' 'item_2' 'item_3' 'item_4')

for item in "${items[@]}"; do
  echo "$item"
done
# => item_1
# => item_2
# => item_3
# => item_4
```
  
It is often useful to print the elements of an array on a single line. The following code will print the elements of the array on a single line:

```bash
echo "${array[*]}"
```

### Functions

Functions are used to group a sequence of commands into a single unit. They are used to perform repetitive tasks. Functions can be called from anywhere in the script. The following example creates a function named <i>hello_world</i> that prints the string <i>Hello World</i> to the standard output (stdout):

```bash
hello_world ()
{
  echo "Hello World!"
}
```

To call the function, use the following syntax:

```bash
hello_world
```

The above function does not take any arguments and does not explicitly return a value. It is possible to pass any number of arguments to the function. It is also possible to return a value from the function, but only an integer from range [0,255] is allowed.

Here is a complete example of a script that defines and uses a function to sum two numbers:

```bash
#!/usr/bin/env bash

sum_two() {
    return $(($1 + $2))
}

sum_two 5 3
echo $?
```

### Pipes

The pipe is used to pass the output of one command as input to the next:

```bash
ps -x | grep chromium
```

### Redirections

But what if you'd want to save the results to a file? Bash has a redirect operator > that may be used to control where the output is delivered.

```bash
cmd >out.log             # Redirect stdout to out.log
cmd 2>err.log            # Redirect stderr to file err.log
cmd 2>&1                 # Redirect stderr to stdout
cmd 1>/dev/null 2>&1     # Silence both stdout and stderr
```

### Formatting and linting

It is important to keep the formatting of your script as consistent as possible. <a href="https://github.com/lovesegfault/beautysh">Beautysh</a> is an amazing tool that helps you to format your script. To use it, just run the following command in a directory where your scripts are located:

```bash
beautysh **/*.sh
```
  
Additionally we advise to use <a href="https://github.com/koalaman/shellcheck">shellcheck</a> for code inspection.

```bash
shellcheck **/*.sh
```

## Available scripts
 
### Intro

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Hello world in Bash.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/hello_world.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Check if condition is true using if statements.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/conditionals.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Example with while loop.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/while_loop.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Example with for loop.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/for_loop.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>A simple script to display the digits of a number.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/digits.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Script to print all numbers in a given interval.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/numbers_in_interval.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Print a christmas tree.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/christmas_tree.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Prompt the user for a response to a given question.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/promt_for_answer.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

### Math

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Arithmetic operations.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/arithmetic_operations.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Sum arguments passed to the script.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/sum_args.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Convert a number from decimal system to binary representation.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/decimal_binary.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Calculate the factorial of an integer.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/factorial.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Is it a prime number?</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/is_prime.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Calculate the square root of a number.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/sqrt.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

### Strings

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Count the number of occurrences of a given character in a string.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/count_char.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Convert all uppercase letters in a text string to lowercase.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/lower.sh">Bash</a></td>
        </tr>
       <tr>
            <td>3</td>
            <td>Convert all lowercase letters in a text string to uppercase.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/upper.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Check if a string is a palindrome.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/is_palindrome.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Check if two strings are anagrams.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/are_anagrams.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Calculate the Hamming Distance of two strings.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/hamming_distance.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Sort a string alphabetically.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/sort_string.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

### Arrays

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Calculate the arithmetic mean of the given n numbers.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/arith_mean.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Find the maximum value in an array.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/max_array.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Find the minimum value in an array.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/min_array.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Script to remove duplicates in an array.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_duplicates_in_array.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

### Files

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Count the files in a directory.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/count_files.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Create a directory.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/make_dir.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Count the number of lines in a text file.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/line_counter.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Get the middle line.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/middle_line.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Remove duplicate lines from a file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_duplicate_lines.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Replace left slashes with right slashes and vice versa.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/switch_slashes.sh">Bash</a></td>
        </tr>   
        <tr>
            <td>7</td>
            <td>Add the text to the beginning of a specified file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/prepend_text_to_file.sh">Bash</a></td>
        </tr>
        <tr>
            <td>8</td>
            <td>Removes all that contain only whitespaces in a given file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_empty_lines.sh">Bash</a></td>
        </tr>
        <tr>
            <td>9</td>
            <td>Rename all files in a directory with a particular extension to a new extension.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/rename_extension.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

### System administration

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Basic system info.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/system_info.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Check the operating system.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/check_os.sh">Bash</a></td>
       </tr>
       <tr>
            <td>3</td>
            <td>Check if root.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/check_if_root.sh">Bash</a></td>
       </tr>      
       <tr>
            <td>4</td>
            <td>Check if apt command is available.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/check_apt_avail.sh">Bash</a></td>
       </tr>
       <tr>
            <td>5</td>
            <td>Check the RAM size.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/ram_memory.sh">Bash</a></td>
       </tr>
       <tr>
            <td>6</td>
            <td>Get CPU temperature.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/cpu_temp.sh">Bash</a></td>
       </tr>
       <tr>
            <td>7</td>
            <td>Get total CPU usage.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/cpu_usage.sh">Bash</a></td>
       </tr>
       <tr>
            <td>8</td>
            <td>Block websites from being visited.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/web_blok.sh">Bash</a></td>
       </tr>
       <tr>
            <td>9</td>
            <td>Make a system backup. Compress files and encrypt the archive.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/backup.sh">Bash</a></td>
       </tr>
       <tr>
            <td>10</td>
            <td>Display processes which might be orphans.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/orphans.sh">Bash</a></td>
       </tr>
       <tr>
            <td>11</td>
            <td>Display processes which might be zombies.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/zombies.sh">Bash</a></td>
       </tr>
    </tbody>
</table>

### Programming workflow

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Remove carriage return from the given files.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_carriage_return.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Replace all diacritical characters in the given files.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_diacritics.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Change all spaces in file names to underscores and convert them to lowercase.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/correct_file_names.sh">Bash</a></td>
       </tr>
       <tr>
            <td>4</td>
            <td>Remove trailing whitespaces from every file in a given directory.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_trailing_whitespaces.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Beautify and format every shell script found in the current repository.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/beautify_script.sh">Bash</a></td>
       </tr>
       <tr>
            <td>6</td>
            <td>Find unused functions and classes in a Python project.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/dead_code.sh">Bash</a></td>
       </tr>
    </tbody>
</table>

### Git

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Reset local repository to match the origin.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/reset_to_origin.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Remove the specified branch, both locally and remotely.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_branch.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Count the number of lines of code in a git repository.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/count_lines_of_code.sh">Bash</a></td>
       </tr>
       <tr>
            <td>4</td>
            <td>Squash n last commits.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/squash_n_last_commits.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Remove n last commits.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_n_last_commits.sh">Bash</a></td>
       </tr>
       <tr>
            <td>6</td>
            <td>Change the date of the last commit.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/change_commit_date.sh">Bash</a></td>
       </tr>
    </tbody>
</table>
  
### Utility

<table>
    <thead>
        <tr>
            <th>#</th>
            <th>Description</th>
            <th>Code</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Find your IP address.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/ip_info.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Empty the trash.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/empty_trash.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Block websites from being visited.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/web_blok.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Extract files based on extension.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/extract.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Check which programs are running on a specific port.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/program_on_port.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Convert month names to numbers and vice versa.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/month_to_number.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Alias all the scripts from a given directory.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/alias_all_the_scripts.sh">Bash</a></td>
        </tr>
        <tr>
            <td>8</td>
            <td>Get a random integer number from the given range.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/rand_int.sh">Bash</a></td>
        </tr>
        <tr>
            <td>9</td>
            <td>Generate a random password of the specified length.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/random_password.sh">Bash</a></td>
        </tr>
        <tr>
            <td>10</td>
            <td>Time execution of a program with the parameters supplied.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/time_execution.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

## Refrences
  
* https://www.gnu.org/software/bash/manual/bash.html
