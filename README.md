# Bash-scripts
Collection of Bash scripts.

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

<h1> When not use Bash? </h1>

* Complex applications.
* GUI.
* Cross-platform portability.
* Calculations.

<h1>Hello world </h1>

```bash
#!/bin/bash
echo "Hello world"
```

<h1>Executing script </h1>

Open the terminal in the directory containing your script.

```bash
chmod u+x filename.sh
./filename.sh
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
if [ $i -eq 10 ]; then        # int comparison
if [ "$name" == "10" ]; then  # string comparison
```

<h1>Pipes </h1>

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

<h1>For loop </h1>

A for loop repeats a sequence of steps a number of times.

```bash
for number in {1..10}
do
  echo "$number "
done
```
