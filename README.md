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

<h1>Command line arguments </h1>

* First argument: <i>$1</i>
* All command line arguments as array: <i>$@</i>
* Number of command line arguments: <i>$#</i>
* The exit status of the last executed command: <i>$?</i>

<h1>If statements </h1>
