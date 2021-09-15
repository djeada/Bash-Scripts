<div align="center">
<a href="https://github.com/djeada/Bash-scripts/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/network"><img alt="GitHub forks" src="https://img.shields.io/github/forks/djeada/Bash-scripts"></a>
<a href="https://github.com/djeada/Bash-scripts/blob/master/LICENSE"><img alt="GitHub license" src="https://img.shields.io/github/license/djeada/Bash-scripts"></a>
<a href=""><img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat"></a>
</div>

# Bash-scripts
A collection of Bash scripts.

<h1>About Bash</h1>

* Scripting languages originated as extensions of command interpreters in operating systems.
* Bourne shell (sh) was the first significant shell. Bash, today's most used Unix shell, is a GNU/FSF enhancement on the Bourne shell.
* Other shells include: C shell (csh), TC shell (tcsh), Dash (dash), Korn shell (ksh), Z shell (zsh).

<h1> What's the purpose of shell scripts? </h1>

* When working on programming projects or doing administrative tasks on servers, usually several command sequences are regularly repeated. This is especially true when working with files and directories, processing text, or doing network configurations. Numerous times, those command sequences exist in many forms and must be adjusted with user input, necessitating the usage of scripts.
* Scripting languages such as Bash improve our processes by including variables, if statements, loops, arrays, and functions, allowing for more sophisticated program flow.
* The actual power of shell script comes from all of the accessible Unix commands.
* Eventually, scripts get too complicated for basic languages such as Bash. At this stage, you should consider utilizing more powerful programming languages, such as Python.
* Shell scripts may also be used to "glue" together more complex Python scripts.

<h1> When should you not use Bash? </h1>

* Complex applications.
* GUI.
* Cross-platform portability.
* Calculations.

<h1>Hello world </h1>

```bash
#!/usr/bin/env bash
echo "Hello world"
```

<h1>Executing script </h1>

Open the terminal in the directory containing your script.

```bash
chmod u+x filename.sh
./filename.sh
```

<h1>Script shebang</h1>

To use the bash interpreter, the first line of a script file must specify the absolute path to the bash executable:

```bash
#!/usr/bin/env bash
```

The bash path in the shebang is resolved and utilized only when a script is launched directly as follows:

```bash
./filename.sh
```

When a bash interpreter is explicitly specified to execute a script, the shebang is ignored:

```bash
bash ./filename.sh
```

<h1>Variables </h1>
  
* Assign the value <i>var="Test"</i>.
* Retrive the value <i>$x</i> or <i>${x}</i>.
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

<h1>Command line arguments </h1>

* First argument: <i>$1</i>
* All command line arguments as array: <i>$@</i>
* Number of command line arguments: <i>$#</i>
* The exit status of the last executed command: <i>$?</i>

<h1>If statements </h1>

Comparison of strings and ints differs. Assume that all values are strings, unless proven otherwise.

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

<h1>For loop</h1>

A for loop repeats a sequence of steps a number of times.

```bash
for number in {1..10}
do
  echo "$number "
done
```

<h1>Array</h1>

Using single quotation marks, create an array:

```bash
array=(1 2 3 4)
```

Create an array with specified element indices like follows:

```bash
array=([3]='elem_a' [4]='elem_b')
```

Insert an elementat (e.g. 'abc') at a given index (e.g. 2):

```bash
array=("${array[@]:0:2}" 'new' "${array[@]:2}")
```

Iterate trough an array:

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
  
A one-liner for printing an array:

```bash
echo "${array[*]}"
```

<h1>Functions</h1>

A simple function:


```bash
#!/usr/bin/env bash

hello_world ()
{
  echo "Hello World!"
}

hello_world
```

Sum two numbers:

```bash
#!/usr/bin/env bash

sum_two() {
    return $(($1 + $2))
}

sum_two 5 3
echo $?
```

<h1>Pipe</h1>

The pipe is used to pass the output of one command as input to the next:

```bash
ps -x | grep chromium
```

<h1>Redirect </h1>

But what if you'd want to save the results to a file? Bash has a redirect operator > that may be used to control where the output is delivered.

```bash
cmd >out.log             # Redirect stdout to out.log
cmd 2>err.log            # Redirect stderr to file err.log
cmd 2>&1                 # Redirect stderr to stdout
cmd 1>/dev/null 2>&1     # Silence both stdout and stderr
```

<h1>Formatting</h1>
<a href="https://github.com/lovesegfault/beautysh">Beautysh</a> is a great way to keep your formatting consistent.

```bash
beautysh **/*.sh
```

<h1>Intro</h1>

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
            <td>Print a christmas tree.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/edit/master/src/christmas_tree.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

<h1>Math</h1>

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
    </tbody>
</table>

<h1>Files</h1>

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
            <td>Bundle together the given files.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/bundle_files.sh">Bash</a></td>
        </tr>
        <tr>
            <td>5</td>
            <td>Get the middle line.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/middle.sh">Bash</a></td>
        </tr>
    </tbody>
</table>

<h1>System administration</h1>

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
            <td>Basic system check.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/system_check.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Check Operating System.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/check_os.sh">Bash</a></td>
       </tr>
       <tr>
            <td>3</td>
            <td>Get CPU temperature.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/cpu_temp.sh">Bash</a></td>
       </tr>
        <tr>
            <td>4</td>
            <td>Make a system backup. Compress files and encrypt the archive.</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/backup.sh">Bash</a></td>
       </tr>
    </tbody>
</table>

<h1>Programming workflow</h1>

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
            <td>Remove the carriage return from the given files.</td>
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
    </tbody>
</table>

<h1>Utility</h1>

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
            <td>Find your IP address</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/ip_info.sh">Bash</a></td>
        </tr>
        <tr>
            <td>2</td>
            <td>Empty the trash</td>
            <td><a href="https://github.com/djeada/Bash-scripts/blob/master/src/empty_trash.sh">Bash</a></td>
        </tr>
    </tbody>
</table>
