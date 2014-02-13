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

Wait, but this looks like it would be really useful on its own!
---------------------------------------------------------------

Thanks! TclTools is released and maintained separately at [karlgluck / TclTools](https://github.com/karlgluck). The version included here is for ensuring compatibility, since this tool is self-contained and "done" as-is. You should use a fresh copy from the main branch if you want to do development. You'll also find a lot of documentation there!
