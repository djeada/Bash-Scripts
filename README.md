<div align="center">
<a href="https://github.com/djeada/Bash-scripts/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/network"><img alt="GitHub forks" src="https://img.shields.io/github/forks/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/blob/master/LICENSE"><img alt="GitHub license" src="https://img.shields.io/github/license/djeada/Bash-scripts"></a>
<a href=""><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat"></a>
</div>

# Bash-scripts
A collection of utility Bash scripts for automating common mundane tasks.

![Screenshot](https://user-images.githubusercontent.com/37275728/186024435-7edf1be2-ca64-4841-98bf-d07cbb362715.png)

## Table of Contents
<!--ts-->

  - [About-Bash](#About-Bash)
    - [What's-the-purpose-of-shell-scripts?](#Whats-the-purpose-of-shell-scripts)
    - [When-should-you-not-use-Bash?](#When-should-you-not-use-Bash)
    - [Hello-world](#Hello-world)
    - [Executing-a-script](#Executing-a-script)
    - [The-shebang](#The-shebang)
    - [Variables](#Variables)
    - [Command-line-arguments](#Command-line-arguments)
    - [If-statements](#If-statements)
    - [For-loops](#For-loops)
    - [Arrays](#Arrays)
    - [Functions](#Functions)
    - [Pipes](#Pipes)
    - [Redirections](#Redirections)
    - [Formatting-and-linting](#Formatting-and-linting)
  - [Available-scripts](#Available-scripts)
    - [Intro](#Intro)
    - [Math](#Math)
    - [Strings](#Strings)
    - [Arrays](#Arrays)
    - [Files](#Files)
    - [System-administration](#System-administration)
    - [Programming-workflow](#Programming-workflow)
    - [Git](#Git)
    - [Utility](#Utility)
  - [Refrences](#Refrences)

<!--te-->

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

To run this script, open the terminal in the directory where the script is located and type the following command:

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
hello_world()
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

sum_two() 
{
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
some_command > out.log            # Redirect stdout to out.log
some_command 2> err.log           # Redirect stderr to file err.log
some_command 2>&1                 # Redirect stderr to stdout
some_command 1>/dev/null 2>&1     # Silence both stdout and stderr
```
  
Complete summary:
  
| Syntax     | StdOut visibility | StdErr visibility | StdOut in file | StdErr in file | existing file |
| --------   | ----------------- | ----------------- | -------------- | -------------- | ------------- |
| >          |   no              |   yes             |   yes          |   no           |  overwrite    |
| >>         |   no              |   yes             |   yes          |   no           |  append       |
| 2>         |   yes             |   no              |   no           |   yes          |  overwrite    |
| 2>>        |   yes             |   no              |   no           |   yes          |  append       |  
| &>         |   no              |   no              |   yes          |   yes          |  overwrite    |    
| &>>        |   no              |   no              |   yes          |   yes          |  append       |  
| tee        |   yes             |   yes             |   yes          |   no           |  overwrite    |  
| tee -a     |   yes             |   yes             |   yes          |   no           |  append       |
| n.e. (*)   |   yes             |   yes             |   no           |   yes          |  overwrite    |  
| n.e. (*)   |   yes             |   yes             |   no           |   yes          |  append       |
| \|& tee    |   yes             |   yes             |   yes          |   yes          |  overwrite    |
| \|& tee -a |   yes             |   yes             |   yes          |   yes          |  append       |  

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
            <td>Prints "Hello, world!" to the console.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/hello_world.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Demonstrates the use of if statements to determine if a condition is true or false.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/conditionals.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Shows the use of a while loop to execute a block of code repeatedly.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/while_loop.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Demonstrates the use of a for loop to iterate over a sequence of elements.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/for_loop.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Displays the digits of a given number, one digit per line.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/digits.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Prints all of the numbers within a specified range, one number per line.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/numbers_in_interval.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Prints a Christmas tree pattern to the console.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/christmas_tree.sh">Bash</a></td>
        </tr>
        <tr>
            <td>8</td>
            <td>Prompts the user for a response to a given question and stores their response in a variable.</td>
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
            <td>Performs basic arithmetic operations (addition, subtraction, multiplication, and division) on two numbers.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/arithmetic_operations.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Calculates the sum of all the arguments passed to it, treating them as numbers.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/sum_args.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Converts a number from the decimal (base 10) system to its equivalent in the binary (base 2) system.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/decimal_binary.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Calculates the factorial of a given integer.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/factorial.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Determines whether a given number is a prime number or not.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/is_prime.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Calculates the square root of a given number.</td>
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
            <td>Counts the number of times a specific character appears in a given string.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/count_char.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Converts all uppercase letters in a given string to lowercase.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/lower.sh">Bash</a></td>
        </tr>
       <tr>
            <td>3</td>
            <td>Converts all lowercase letters in a given string to uppercase.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/upper.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Checks if a given string is a palindrome, i.e., a word that is spelled the same way forwards and backwards.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/is_palindrome.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Checks if two given strings are anagrams, i.e., if they are made up of the same letters rearranged in a different order.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/are_anagrams.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Calculates the Hamming Distance between two strings, i.e., the number of positions at which the corresponding characters are different.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/hamming_distance.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Sorts a given string alphabetically, considering all letters to be lowercase.</td>
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
            <td>Calculates the arithmetic mean of a given list of numbers.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/arith_mean.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Finds the maximum value in a given array of numbers.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/max_array.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Finds the minimum value in a given array of numbers.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/min_array.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Removes duplicates from a given array of numbers.</td>
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
            <td>Counts the number of files in a specified directory.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/count_files.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Creates a new directory with a specified name.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/make_dir.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Counts the number of lines in a specified text file.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/line_counter.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Gets the middle line from a specified text file.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/middle_line.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Removes duplicate lines from a specified file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_duplicate_lines.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Replaces all forward slashes with backward slashes and vice versa in a specified file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/switch_slashes.sh">Bash</a></td>
        </tr>   
        <tr>
            <td>7</td>
            <td>Adds specified text to the beginning of a specified file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/prepend_text_to_file.sh">Bash</a></td>
        </tr>
        <tr>
            <td>8</td>
            <td>Removes all lines in a specified file that contain only whitespaces.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_empty_lines.sh">Bash</a></td>
        </tr>
        <tr>
            <td>9</td>
            <td>Renames all files in a specified directory with a particular extension to a new extension.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/rename_extension.sh">Bash</a></td>
        </tr>
        <tr>
            <td>10</td>
            <td>Strips digits from every string found in a given file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/strip_digits.sh">Bash</a></td>
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
            <td>Retrieves basic system information, such as hostname and kernel version.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/system_info.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Determines the type and version of the operating system running on the machine.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/check_os.sh">Bash</a></td>
       </tr>
       <tr>
            <td>3</td>
            <td>Checks whether the current user has root privileges.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/check_if_root.sh">Bash</a></td>
       </tr>      
       <tr>
            <td>4</td>
            <td>Checks if the `apt` command, used for package management on Debian-based systems, is available on the machine.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/check_apt_avail.sh">Bash</a></td>
       </tr>
       <tr>
            <td>5</td>
            <td>Retrieves the size of the machine's random access memory (RAM).</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/ram_memory.sh">Bash</a></td>
       </tr>
       <tr>
            <td>6</td>
            <td>Gets the current temperature of the machine's central processing unit (CPU).</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/cpu_temp.sh">Bash</a></td>
       </tr>
       <tr>
            <td>7</td>
            <td>Retrieves the current overall CPU usage of the machine.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/cpu_usage.sh">Bash</a></td>
       </tr>
       <tr>
            <td>8</td>
            <td>Blocks certain websites from being visited on the local machine by modifying the `hosts` file.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/web_blok.sh">Bash</a></td>
       </tr>
       <tr>
            <td>9</td>
            <td>Creates a backup of the system's files, compress the backup, and encrypt the resulting archive for storage. The backup can be used to restore the system in case of data loss or system failure.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/backup.sh">Bash</a></td>
       </tr>
       <tr>
            <td>10</td>
            <td>Displays processes that are not being waited on by any parent process. Orphan processes are created when the parent process terminates before the child process.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/orphans.sh">Bash</a></td>
       </tr>
       <tr>
            <td>11</td>
            <td>Displays processes that are in an undead state, also known as a "zombie" state. Zombie processes are processes that have completed execution but still have an entry in the process table.</td>
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
            <td>Removes the carriage return character (`\r`) from the given files, which may be present in files transferred between systems with different line ending conventions.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_carriage_return.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Replaces all characters with diacritical marks in the given files with their non-diacritical counterparts. Diacritical marks are small signs added above or below letters to indicate different pronunciations or tones in some languages.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_diacritics.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Changes all spaces in file names to underscores and convert them to lowercase. This can be useful for making the file names more compatible with systems that do not support spaces in file names or for making the file names easier to read or type.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/correct_file_names.sh">Bash</a></td>
       </tr>
       <tr>
            <td>4</td>
            <td>Removes any trailing whitespace characters (spaces or tabs) from the end of every file in a given directory. Trailing whitespace can cause formatting issues or interfere with certain tools and processes.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_trailing_whitespaces.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Formats and beautify every shell script found in the current repository. This can make the scripts easier to read and maintain by adding consistent indentation and whitespace.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/beautify_script.sh">Bash</a></td>
       </tr>
       <tr>
            <td>6</td>
            <td>Finds functions and classes in a Python project that are not being used or called anywhere in the code. This can help identify and remove unnecessary code, which can improve the project's performance and maintainability.</td>
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
            <td>Resets the local repository to match the state of the remote repository, discarding any local commits and changes. This can be useful for starting over or synchronizing with the latest version on the remote repository.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/reset_to_origin.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Deletes the specified branch both locally and on the remote repository. This can be useful for removing branches that are no longer needed or for consolidating multiple branches into a single branch.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/remove_branch.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Counts the total number of lines of code in a git repository, including lines in all branches and commits. This can be useful for tracking the size and complexity of a project over time.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/count_lines_of_code.sh">Bash</a></td>
       </tr>
        <tr>
            <td>4</td>
            <td>Combine multiple commits into a single commit. This can be useful for simplifying a commit history or for cleaning up a series of small, incremental commits that were made in error.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/squash_n_last_commits.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Remove the <i>n</i> last commits from the repository. This can be useful for undoing mistakes or for removing sensitive information that was accidentally committed.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/remove_n_last_commits.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Changes the date of the last commit in the repository. This can be useful for altering the commit history for cosmetic purposes.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/change_commit_date.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Downloads all of the public repositories belonging to a specified user on GitHub. This can be useful for backing up repositories.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/download_all_github_repos.sh">Bash</a></td>
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
            <td>Finds the public IP address of the device running the script.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/ip_info.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Deletes all files in the trash bin.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/empty_trash.sh">Bash</a></td>
        </tr>
        <tr>
            <td>3</td>
            <td>Extracts files with a specified extension from a given directory.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/extract.sh">Bash</a></td>
        </tr>
        <tr>
            <td>4</td>
            <td>Determines which programs are currently using a specified port number on the local system.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/program_on_port.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Converts month names to numbers and vice versa in a string. For example, "January" to "1" and "1" to "January".</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/month_to_number.sh">Bash</a></td>
        </tr>
        <tr>
            <td>6</td>
            <td>Creates command aliases for all the scripts in a specified directory, allowing them to be run by simply typing their names.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/alias_all_the_scripts.sh">Bash</a></td>
        </tr>
        <tr>
            <td>7</td>
            <td>Generates a random integer within a given range. The range can be specified as arguments to the script.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/rand_int.sh">Bash</a></td>
        </tr>
        <tr>
            <td>8</td>
            <td>Generates a random password of the specified length, using a combination of letters, numbers, and special characters.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/random_password.sh">Bash</a></td>
        </tr>
        <tr>
            <td>9</td>
            <td>Measures the time it takes to run a program with the specified input parameters. Output the elapsed time in seconds.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/time_execution.sh">Bash</a></td>
        </tr>
        <tr>
            <td>10</td>
            <td>Downloads the audio from a YouTube video or playlist in MP3 format. Specify the video or playlist URL and the destination directory for the downloaded files.</td>
            <td><a href="https://github.com/djeada/Bash-Scripts/blob/master/src/youtube_to_mp3.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

## Refrences

* https://www.gnu.org/software/bash/manual/bash.html
* http://mywiki.wooledge.org/BashGuide
* https://wiki.bash-hackers.org/

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)
