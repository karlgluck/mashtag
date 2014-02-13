TclTools
========

This library contains a lot of common time-saving functionality into a single package:

+ Inline self-tests with [Jasmine-like](http://pivotal.github.io/jasmine/) syntax
+ [Tcl language extensions](./1.0/src/tclx.tcl) such as static variables, once-executed code and forsearch loops
+ Runtime sanity checking with [`assert`](./1.0/src/assert.tcl) & [`confirm`](./1.0/src/confirm.tcl)
+ List, set & stack manipulation
+ Simple command-line interface creation with built-in usage guides
+ Linux terminal commands for cursor position, colors, and styles like awesome blinking text
+ `@` function framework that allows procedures to be toggled between normal behavior and no-ops
+ Functions for temporary files/directories that automatically delete themselves
+ Nonblocking I/O
+ Debug- or release-mode code gates
+ Non-code assumption tracking with [@assume](./1.0/src/assume.tcl) to nail down pesky bugs

Sounds cool! How do I use it?
-----------------------------

Download the repository and extract the contents. In your Tcl program, add:


```tcl
source "/path/to/repo/1.0/package.tcl"
package require tcltools
```

What about self-testing?
------------------------

This library has inline self-tests written immediately after most procedure declarations. The tests can be launched by running [`diagnose`](./1.0/test/diagnose) in the test directory. If all goes well, you'll get an output like this:

```
####################################################################################################
#                                                                                                  #
#                                        ALL 170 TESTS PASSED                                      #
#                                                                                                  #
####################################################################################################


tcltools.diagnostics.test

tcltools.diagnostics                                                                  PASS
  Detects constant expressions                                                        PASS
  Evaluates expressions and variables                                                 PASS
  Handles variable expressions from outside 'it' scope                                PASS
  An @describe subcontext                                                             PASS
    Does not bring in variables from the parent @describe context                     PASS
    Can use 'upvar' to share variables with the parent @describe context              PASS
  beforeEach                                                                          PASS
    runs before the first 'it'                                                        PASS
    runs before every subsequent 'it'                                                 PASS
  afterEach                                                                           PASS
    doesn't run until after the first 'it'                                            PASS
    runs after the first 'it'                                                         PASS
    runs after every 'it'                                                             PASS


         22 passed / 0 failed (100.00%)

...

 stack operations                                                                      PASS
   lvarpush                                                                            PASS
     adds a value to an empty list                                                     PASS
     adds another value the list                                                       PASS
     returns the list variable                                                         PASS
   lvarpop                                                                             PASS
     removes a value from the list                                                     PASS
     removes the last pushed value                                                     PASS
     does nothing when the list is empty                                               PASS
     returns 0 when called with an output variable on an empty list                    PASS
     returns 1 when called with an output variable on a populated list                 PASS
   lvartop                                                                             PASS
     returns the last value pushed to a list                                           PASS
     returns 0 when called with an output variable on an empty list                    PASS
     returns 1 when called with an output variable on a populated list                 PASS


         13 passed / 0 failed (100.00%)


####################################################################################################
#                                                                                                  #
#                                        ALL 170 TESTS PASSED                                      #
#                                                                                                  #
####################################################################################################
```



Code Examples
=============


[@on, @off, @proc](./pkgIndex.tcl)
----------------------------------

These functions control `@` procedures that can be toggled between normal behavior and running a no-op.

```tcl
@on print
@proc print {text} { puts stdout $text }
@print "This will write text to the screen. Hello World!"
@off print
@print "This will do nothing."
@on print
@print "But this will print again!"
```
Use `@proc` to declare procedures just like `proc` that have this toggleable behavior. Tcltools uses this internally quite extensively to allow debug/release code and allow self-testing to be declared inline and enabled as necessary.

`@proc` methods are off by default. However, the order of declaration between `@on`/`@off`/`@proc` is not important so if a procedure is set `@on` before it is declared, it will be enabled. The main thing to remember is that the method cannot be used until it is defined with `@proc`.

[@debug, @release](./1.0/src/debug_release.tcl)
-----------------------------------------------

These methods can be used to write code or code blocks that executes only in debug or release mode, or determine whether debug or release mode is currently active. Code is in release mode unless overridden manually (using `@on debug ; @off release`) or the DEBUG environment variable is set to 1.

They return 1 if function is enabled:

```tcl
if {[@debug] && some_condition} {...}
set is_in_release_mode [@release]
```

They conditionally execute a single statement:

```tcl
@debug puts stdout "This will only be printed in debug mode"
@release puts stdout "This only gets printed in release mode"
```

Finally, they conditionally execute a block of code:

```tcl
@debug {
    set message "Hello debug-mode world!"
    puts stdout $message
}
```


[@assert](./1.0/src/assert.tcl)
-------------------------------

`@assert` works just like `assert(...)` in C but can check any number of independent expressions in debug mode. It is a no-op if `[@release] == 1`.

```tcl
@assert {$input == "expected"} {1 >= $zero}
```

[@assume](./1.0/src/assume.tcl)
-------------------------------

Often, programmers have to use their judgement and make non-obvious, hard-to-test or potentially problematic assumptions when writing complex code. When a bug is caused by a mistaken assumption, the issue can often be hard to track down. `@assume` is written to help easily identify the assumptions made in code that could have lead to a fault. 

Whenever a programmer writes code that makes one of these assumptions, they write:

```tcl
@assume "Some description of the assumption, justification, and side-effects."
``` 

During a bug-hunt, developers can turn on assumption reporting, run the app and print a report of how many times (and where) the various assumptions were relied on.

```tcl
@on assume
@on assume.callback
@proc assume.callback {count caller phrase} {
    # this will be called after the top function in the call stack containing a call
    # to @assume has returned
    puts [format {%-5s %30s %s} $count $caller $phrase]
}
```

Because of how the `@assume` function works, it is best to contain your entire application within a single *main* function that only returns when the application exits, and exits only by returning (rather than via `exit` or similar mechanisms).


[@confirm](./1.0/src/confirm.tcl)
---------------------------------

I invented confirm many years ago and include it in almost every big project I write. It was built to satisfy a very simple idea: assertions are great, but if an assertion fails the program should do whatever it can to recover safely and not crash.

```tcl
confirm {$username ne ""} else {set username "###DEFAULT###"}
confirm {[llength $lst] > 0} then {
    set list [lassign $lst top]
    puts $top
}
```

File-System Functions
=====================

[fmake_tmp_dir](./1.0/src/fileutils.tcl)
----------------------------------------

Creates a temporary directory that is deleted when the calling procedure exits.

```tcl
proc demo {} {
    set path [fmake_tmp_dir]
    fwrite $path/helloworld.txt "Hello, world!"
# the $path directory and all subfiles/folders will be deleted here
}
```


[fmake_tmp_file](./1.0/src/fileutils.tcl)
-----------------------------------------

Creates a temporary file that is deleted when the calling procedure exits.

```tcl
proc demo {} {
    set path [fmake_tmp_file]
    fwrite $path "hello!"
# the file at $path will be deleted here
}
```

[fget_lines](./1.0/src/fileutils.tcl)
-------------------------------------

Reads up to block_size bytes at a time from the input file pointer and puts them into the variable named. This is *much* faster than calling`gets` repeatedly for files with many lines. 

The input file pointer must be seek-able. Don't use this if the FP is a pipe, for example.

```tcl
set fp [open "input_file.txt" "r"]
set block_size 512000
while {[fget_lines $fp lines $block_size]} {
    foreach line $lines {
        # do something for this line
    }
}
```


[fforeach_line](./1.0/src/fileutils.tcl)
----------------------------------------

Runs a loop, setting the `line` variable to each line of a file.  This uses batch file reading provided by `fget_lines` so it is very fast.  The input file pointer must be seekable.

```tcl
fforeach_line line [set fp [open "input_file.txt" "r"]] {
    # ... do line processing with normal flow-control semantics
    if { $condition } then continue
    # stuff like this works, too
    puts "at position [tell $fp] in file"
}
```

[fsize](./1.0/src/fileutils.tcl)
--------------------------------

Returns the size of the file referenced by the input file pointer in bytes. If the file pointer is not seekable, this will return `-1`.

```tcl
set bytes [fsize $fp]
```

[fread](./1.0/src/fileutils.tcl)
--------------------------------

Reads and returns the contents of a text file.

```tcl
set contents [fread $path]
```

[fread_lines](./1.0/src/fileutils.tcl)
--------------------------------------

Reads and returns the contents of a file as a list of lines.

```tcl
set lines [fread_lines $path]
```


[fread_binary](./1.0/src/fileutils.tcl)
---------------------------------------

Reads and returns the contents of a file using binary translation.

```tcl
set contents [fread_binary $path]
```


[fread_nonblocking_dispatch](./1.0/src/fileutils.tcl), [fread_nonblocking_collect](./1.0/src/fileutils.tcl)
-----------------------------------------------------------------------------------------------------------

Provides easy access to the nonblocking I/O mode of `fread` where files are opened in parallel. This is faster than opening, reading and closing many files sequentially.

After adding a bunch of paths using `fread_nonblocking_dispatch`, use `fread_nonblocking_collect` to wait for all of the files to be read and obtain their contents as an array. Each call opens a new file descriptor, so you may want to call this in smaller batches. 

```tcl
fread_nonblocking_dispatch $paths
foreach {path contents} [fread_nonblocking_collect] {
    ...
}
```

[fappend](./1.0/src/fileutils.tcl)
----------------------------------

Appends each subsequent argument as text to the path specified in the first argument.

```tcl
fappend $path "Hello, " "World" "!"
```

[fwrite](./1.0/src/fileutils.tcl)
---------------------------------

Sets the contents of a file.

```tcl
fwrite $path "These arguments collectively " "replace everything in" "the file."
```

[fwrite_lines](./1.0/src/fileutils.tcl)
---------------------------------------

Sets the contents of a file using lists of lines.

```tcl
fwrite $path [list "One" "list" "entry"] [list "per line" "in the file"]
```

[fwrite_binary](./1.0/src/fileutils.tcl)
----------------------------------------

Overwrites a file with binary data from one or more arguments.

```tcl
fwrite_binary $path $data0 $data1
```

[realpath](./1.0/src/fileutils.tcl) 
-----------------------------------

Returns the normalized path to a file or directory without passing through soft-links.

```tcl
set path [realpath $path]
```

List Functions
==============

[lvarcat](./1.0/src/lists.tcl)
------------------------------

Appends values to a list

```tcl
 $ set list_var [list "1" "2" "3"]
 $ lvarcat list_var [list "a" "b" "c"]
 $ puts $list_var
 1 2 3 a b c
```

[lvarpush](./1.0/src/lists.tcl), [lvarpop](./1.0/src/lists.tcl), [lvartop](./1.0/src/lists.tcl)
-----------------------------------------------------------------------------------------------

These 3 functions provide the usual set of stack operations using a list variable.

```tcl
set list_var [list]
lvarpush list_var "One"
lvarpush list_var "Two"
set top_val [lvartop list_var] ; # top_val is now "Two"
set has_contents [lvartop list_var top_val_2] ; # has_contents = 1, top_val_2 = "Two"
if {[lvarpop list_var popped]} {
    # popped is now set to "Two" and this code is executed
    # because lvarpop returns 1 if it pops a value
}
set has_contents_2 [lvarpop list_var popped_2]
# has_contents_2 is 1 because popped_2 was set to "One"
set has_contents_3 [lvarpop list_var popped_3]
# has_contents_3 is 0 because nothing was left in the list. popped_3 is not set.
set popped [lvarpop list_var]
# popped is set to {} because nothing was in the list, but this is
# indistinguishable from popping an empty element!
```

[lmin](./1.0/src/lists.tcl), [lmax](./1.0/src/lists.tcl)
--------------------------------------------------------

Returns the numerically smallest (`lmin`) or largest (`lmax`) values from the elements of the list. 

```tcl
set numbers [list 5 1 3 4 28 12e4]
set smallest [lmin $numbers] ; # smallest == 1
set largest  [lmax $numbers] ; # largest == 12e4
```

[lmedian](./1.0/src/lists.tcl)
------------------------------

Returns the median of a list of numbers. The list must be all integers or all reals, but this function works for both types.

```tcl
set m [lmedian [list -5 0 12 0 19 0 0 0]] # m == 0
```

[laverage](./1.0/src/lists.tcl)
-------------------------------

Returns the average of a list of integers or reals. The result is a real.

```tcl
set avg [laverage [list -3 2.5 9 16 9 278.2]]
```

[lempty](./1.0/src/lists.tcl), [lnotempty](./1.0/src/lists.tcl)
---------------------------------------------------------------

Shortcut for determining whether the list is empty or has at least one element. Useful for making `if {}` statements more readable.

```tcl
if {[lempty $input]} { error "needs input!" }
if {[lnotempty $some_var]} { .. }
```

[lunique](./1.0/src/lists.tcl)
------------------------------

Returns a unique list of entries from the given input. Order is preserved!

```tcl
set u [lunique [list a b b c c c -1]] ; # u == {a b c -1}
```

[lreorder](./1.0/src/lists.tcl)
-------------------------------

Reorders the first list so that any elements present in the second list are in the same order as those in the second list, and any elements not present in the second list are moved to the end.

This is handy for using in combination with `intersect3` when you want the order of the intersected elements to be preserved. 

```tcl
set contents [list "foo" "e" "d" "c" "b" "a"]
set order [list "a" "Q" "b" "Z" "c" "d" "f" "e"]
set reordered [lreorder $contents $order]
# reordered == {a b c d e foo}
```

[lintersect](./1.0/src/lists.tcl)
---------------------------------

Returns the intersection of two lists, preserving duplicates but not necessarily order.

```tcl
set r [lintersect {a a b d} {a a c d}]
# r == {d a a}
```

[lsubtract](./1.0/src/lists.tcl)
--------------------------------

Returns the subtraction of list B from list A. Order is not preserved. If you want to preserve order, use `lreorder` on the output with one of the input lists.

```tcl
set r [lsubtract {a a b c} {a b d}]
# r contains only "c" and "a" in either order
```

[intersect3](./1.0/src/lists.tcl)
---------------------------------

Performs the intersection of two lists to separate elements into only those present in the first, those present in both, and only those present in the second. Unlike naive implementations, duplicates are preserved.

The most common way to use this is to `lassign` the output.

```tcl
lassign [intersect3 {a a b 1 2 x} {a b b 1 2 y}] first both second
# first == {a x}
# both == {1 2 a b}
# second == {b y}
```

Note that `both` and `second` each contain `b` because this value was duplicated. 

[lprocess](./1.0/src/lists.tcl)
-------------------------------

Invokes a function on sets of one or more elements in the list, mapping each set of parmeters to that number of consecutive elements in the list and invoking the code as if called in caller's scope.

There are two ways to call this: by defining a new function (a lambda) or by invoking an existing procedure.  If a lambda is used, the syntax is:

```tcl
lprocess $list {arg1 arg2 arg3...} {code...}
```

If an existing function is used, the syntax is:

```tcl
lprocess $list function_name
```

A new list is built from the returned values of the code.  Values are concatenated to the list being returned, so a return value of `{}` will add nothing to the output and can be used to build a filter.

[linterleave](./1.0/src/lists.tcl)
----------------------------------

Turns `{1 2 3} {a b c} {! @ #}` into `{1 a ! 2 b @ 3 c #}`

```tcl
set l123 [linterleave $l1 $l2 $l3]
```

[ltranspose](./1.0/src/lists.tcl)
---------------------------------

Operates on an array-of-arrays representing a 2d matrix to swap the rows and columns. This turns `{{1 2} {3 4} {5 6}` into `{{1 3 5} {2 4 6}}`.

```tcl
set output [ltranspose $list2d]
```

[forsearch](./1.0/src/tclx.tcl)
-------------------------------

The `forsearch` construct allows you to express a common functional idea:  look through each element in a list until an element meeting some requirements is found, then break.  If no element is found, execute some code.

```tcl
forsearch line $lines {
    if {[regexp $RE $line]} { break }
} else {
    # no line matched the regex, so do some default action
}
```

[upvar_closest](./1.0/src/tclx.tcl)
-----------------------------------

Finds the closest variable called `$name` in the call-stack and brings it into the caller's context.  The second parameter is what to alias the variable to; if not defined, it will use the first parameter's value by default.

```tcl
proc foo {} {
    upvar_closest bar ; # find and bring in "bar" and call it "bar" in this context
    upvar_closest baz bat ; # bring in "baz" and call it "bat" in this context
}
```

[interpreter_state](./1.0/src/tclx.tcl)
---------------------------------------

Saves the entire program state into a string that can be evaluated by the Tcl interpreter to restore the program's global state.  This lets you save an entire program to disk and load it back later, or fork a thread with duplicated global state.

```tcl
set state_code [interpreter_state]
...
eval $state_code ; # restore global variables, function definitions, etc.
```

[on_final_return](./1.0/src/tclx.tcl)
-------------------------------------

Schedules a piece of code to be run when the top-level function in the call stack returns.

For complex programs with a 'main' function, this is effectively when the program terminates as long as termination is not done by killing the interpreter (i.e. it won't trigger if `exit` is used).

```tcl
proc bar {} {
    on_final_return { puts "returning!" }
}
proc foo {} {
    ...
    bar
    ...
    # the code will print "returning!" here
}
foo
```

[static](./1.0/src/tclx.tcl)
----------------------------

Declares a static variable--one that keeps its value between calls to the function. Can be initialized with a value when declared. If not provided, the value will default to 0.

```tcl
proc foo {} {
    static x 0
    puts [incr x]
}
foo ; # puts "1"
foo ; # puts "2"
foo ; # puts "3"
```

[once](./1.0/src/tclx.tcl)
--------------------------

Declares that a section of code should execute only the first time it is encountered.

```tcl
proc foo {} {
    once { puts "First time!" }
}
foo ; # puts "First time!"
foo ; # (nothing)
foo ; # (nothing)
```

[unique_key](./1.0/src/tclx.tcl)
--------------------------------

Returns a string that is guaranteed to be unique every time it is called within a series of interpreters. It is not guaranteed unique among separate threads running at the same time, though.

```tcl
set value [unique_key]
```

Diagnostics
===========

Use `package require tcltools.diagnostics` to get access to commands in this module. Note that `@describe` can be written without the package being included, but will simply not function since it is `@off` by default.

[@describe](./1.0/src/diagnostics/diagnostics.tcl)
--------------------------------------------------

Defines a testing framework for TclTools.  This framework can be accessed by asking for the package `tcltools.diagnostics`.  The functionality it provides is based on the Jasmine library for JavaScript.

None of this code is executed unless `@describe` is turned `@on`.

###`@describe "thing" { <code> }`
Can have other descriptions in it, or functionality descriptions.

###`it "performs some function" { <code> }`
A description of some functionality that is being performed.  Contains expectations.  This is evaluated in the context of an `@describe`

###`beforeEach { <code> }`
Evaluates some code before every "it" in an @describe block

###`afterEach { <code> }`
Evaluates some code after every "it" in an @describe block

###`expect {expression} to ...`
Declares an expectation that a certain expression evaluates. If an expectation is not met, execution continues as normal (it does not abort). Results are logged. `...` can be one of:
 + `be undefined`
 + `be defined`
 + `be truthy`
 + `be falsy`
 + `be less than <value>`
 + `be greater than <value>`
 + `match {regex}`
 + `contain <list_item>`

###Examples

```tcl
@debug @describe "confirm (@debug mode)" {
    beforeEach {
        catch { unset set_by_confirm }
    }
    it "throws an error on failure" {
        expect {confirm {0} then {}} to throw an error
    }
    it "executes 'then' on success" {
        confirm {1} then {set set_by_confirm 1}
        expect {set_by_confirm} to be defined
    }
    it "never executes 'else'" {
        catch { confirm {0} else { set set_by_confirm 1 } }
        expect {set_by_confirm} to be undefined
    }
    it "evaluates arguments even without then/else clauses" {
        catch { confirm {[set set_by_confirm 1]} }
        expect {set_by_confirm} to be defined
    }
}
```

```tcl
@describe "lsubtract" {
    set abc [list "a" "b" "c"]

    it "does nothing with empty lists" {
        expect {[lsubtract [list] [list]] eq [list]} to be truthy
        expect {[lsubtract [list] [list "a" "b" "c"]] eq [list]} to be truthy
        expect {[lsubtract $abc [list]] eq $abc} to be truthy
        expect {[lsubtract $abc $abc] eq [list]} to be truthy
    }
    it "subtracts the second list from the first" {
        expect {[lsubtract $abc [list "b"]]} to contain "a"
        expect {[lsubtract $abc [list "b"]]} to not contain "b"
        expect {[lsubtract $abc [list "b"]]} to contain "c"

        expect {[lsubtract $abc [list "a" "b"]]} to not contain "a"
        expect {[lsubtract $abc [list "a" "b"]]} to not contain "b"
        expect {[lsubtract $abc [list "a" "b"]]} to contain "c"
    }
}
```

Terminal
========

Use `package require tcltools.terminal` to get access to commands in this module.

[TOOL_CLI](./1.0/src/terminal/terminal.tcl)
-------------------------------------------

Call this first in a command-line tool to make it easy to process POSIX and Unix-style command line arguments.

Single-letter flags are all off by default, but can be toggled "on" by using a single dash (e.g. `-abcD` sets a, b, c, and D to on).  All double-dash parameters take a single argument, and, for `--<name>`, the value of the variable $name is set to that argument.  Parameters that are not switched are assigned into the list of trailing variables, in order.  The list of values not assigned is returned.

Example format of `flags`:

```
{
        "a" "Turn on processing of all elements"
        "R" "Recurse all directories"
}
```

Example format of `switches`:

```
{
        "recursive" "Control recursion mode.  Overrides -R if set."   -
        "verbosity" "Set the verbosity of debug output."              "3"
}
```

Switches and flags are returned in the CLI global.

The `--help` switch, `-h` flag and `?` arguments are always predefined to print help information.  When one of these is encountered, the tool exits.  


*Example:*

```tcl
package require tcltools.terminal
TOOL_CLI "This tool does something awesome!" {
    "v"     "Toggle verbose output"
} {
    "path"  "The path to an input file." -
    "eval"  "Statement to evaluate (for debugging)" ""
}
```

[terminal](./1.0/src/terminal/terminal.tcl)
-------------------------------------------

Terminal commands that manipulate stdout in Linux.

###Misc

*`terminal initialize`*
Automatically called on load to initialize the internal state.  Can be called again to determine whether the console supports special output (return value = 1).

###Positioning


*`terminal setpos <row> <column>`*
Sets the current cursor position to a defined <row> <column> location

*`terminal savepos`*
Saves the current cursor position so it can be loaded later

*`terminal loadpos`*
Moves the cursor to the last saved cursor position

*`terminal up <lines>`*
Move the cursor up by <rows> rows

*`terminal down <lines>`*
Move the cursor down by <rows> rows

*`terminal left <columns>`*
Move the cursor left by <columns> columns

*`terminal right <columns>`*
Move the cursor right by <columns> columns

*`terminal home`*
Move the cursor to the start of the line

###Erasing output

*`terminal cls`*
Erases all text on the screen and resets the cursor position to (0,0)

*`terminal clearline`*
Erases text from the current cursor position to the end of the line

###Text Effects

All effects below last until the next `terminal reset`

*`terminal color <color>`*
Changes the foreground color of text to one of: `black` `red` `green` `yellow` `blue` `magenta` `cyan` `white` `default`

*`terminal bgcolor <color>`*
Changes the background color of text to one of: `black` `red` `green` `yellow` `blue` `magenta` `cyan` `white` `default`

*`terminal emphasis`*
Emphasize text (actual effect varies)

*`terminal dim`*
Use darker version of color

*`terminal underline`*
Underline text

*`terminal flash`*
Blink text

*`terminal reverse`*
Invert colors

*`terminal invisible`*
Instead of printing, do nothing but move cursor as if text were printed

*`terminal reset`*
Remove all current text effects and reset to default


###String Output

*`terminal write <strong> ?<arg 0>? ?<arg 1>?`*

Allows the rest of the commands to be accessed in text strings via markup.  Based on an implementation from http://wiki.tcl.tk/37261.

```
POSITIONING
    <tpos> : terminal setpos @ @ (where @ @ are the next two arguments to 'terminal write')
    <tsp>  : terminal savepos
    <tlp>  : terminal loadpos
    <tu>   : terminal up @ (where @ is the next argument to 'terminal write')
    <td>   : terminal down @ (where @ is the next argument to 'terminal write')
    <tl>   : terminal left @ (where @ is the next argument to 'terminal write')
    <tr>   : terminal right @ (where @ is the next argument to 'terminal write')
    <th>   : terminal home

ERASING OUTPUT
    <cls> : terminal cls
    <clr> : terminal clear line ("row")

TEXT EFFECTS
    <e> : terminal emphasis
    <d> : terminal dim
    <u> : terminal underline
    <f> : terminal flash
    <v> : terminal reVerse
    <i> : terminal invisible
    </> : terminal reset

    <k> : terminal color black
    <r> : terminal color red
    <g> : terminal color green
    <y> : terminal color yellow
    <b> : terminal color blue
    <m> : terminal color magenta
    <c> : terminal color cyan
    <w> : terminal color white
    <d> : terminal color default

    <kb> : terminal bgcolor black
    <rb> : terminal bgcolor red
    <gb> : terminal bgcolor green
    <yb> : terminal bgcolor yellow
    <bb> : terminal bgcolor blue
    <mb> : terminal bgcolor magenta
    <cb> : terminal bgcolor cyan
    <wb> : terminal bgcolor white
    <db> : terminal bgcolor default
```

###Examples

Demo code is available in [terminal.demo](./1.0/test/terminal.demo):

```tcl

package require tcltools.terminal

terminal write "<cls><e><r>Hello there!</>\n"
terminal write "  * Hello!!<tsp><td>" 5
terminal write " <b>This text will show up in a weird place!</>\n"
terminal write "<tlp>Then this text will be back where we were before!"

terminal write "\n\n"
terminal color blue
terminal write "This is in blue!"
terminal emphasis
terminal write "This is emphasized!"
terminal reset
terminal write "\nNow we are reset.\n\n\n"
```

