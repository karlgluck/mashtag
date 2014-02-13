####################################################################################################
#
#  Useful functions for tools run from the terminal.
#
#  Allows easy definition of a command-line interface, colorized terminal output, and more.
#
#  Authors:
#    Karl Gluck
#
#---------------------------------------------------------------------------------------------------
namespace eval tcltools {}
namespace eval _tcltools {}


#---------------------------------------------------------------------------------------------------
# Call this first in a command-line tool to make it easy to process POSIX and Unix-style command
# line arguments.
#
# Single-letter flags are all off by default, but can be toggled "on" by using a single dash
# (e.g. -abcD sets a, b, c, and D to on).  All double-dash parameters take a single argument, and,
# for --<name>, the value of the variable $name is set to that argument.  Parameters that are not
# switched are assigned into the list of trailing variables, in order.  The list of values not
# assigned is returned.
#
# Example format of 'flags':
#   {
#       "a" "Turn on processing of all elements"
#       "R" "Recurse all directories"
#   }
#
# Example format of 'switches':
#   {
#       "recursive" "Control recursion mode.  Overrides -R if set."   -
#       "verbosity" "Set the verbosity of debug output."              "3"
#   }
#
# Switches and flags are returned in the CLI global.
#
# The "--help" switch, "-h" flag and "?" arguments are always predefined to print help information.
# When one of these is encountered, the tool exits.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc TOOL_CLI {description flags switches args} {
    global argv
    global CLI

    # save for printing help
    set all_flags $flags
    set all_switches $switches
    set all_args $args

    set a $argv

    # Disable all flags by default
    set letters {a b c d e f g h i j k l m n o p q r s t u v w x y z}
    foreach letter $letters { set CLI($letter) 0 }
    foreach letter $letters { set CLI([string toupper $letter]) 0 }

    # Set default values of switches
    array set required_switches {}
    foreach {name desc value} $switches {
        if {$value eq "-"} {
            set required_switches($name) 1
        } else {
            set CLI($name) $value
        }
    }

    set display_help 0

    # Pull in all arguments
    while {[llength $a]} {
        set a [lassign $a top]
        if {[string range $top 0 1] eq "--"} {
            set name [string range $top 2 end]
            if {![llength $a]} {
                puts stderr "Missing argument for switch $top"
                exit
            }
            set a [lassign $a value]
            if {$name eq "help"} {
                set display_help 1
                break
            } else {
                set CLI($name) $value
                catch { unset required_switches($name) }
            }
        } elseif {[string index $top 0] eq "-"} {
            set flags [split [string range $top 1 end] {}]
            foreach flag $flags {
                set CLI($flag) 1
            }
            if {$CLI(H) || $CLI(h)} {
                set display_help 1
                break
            }
        } else {
            set a [lassign $a value]
            if {$value eq "?"} {
                set display_help 1
                break
            } else {
                # assign to next argument
                set args [lassign $args top]
                set CLI($top) $value
            }
        }
    }

    foreach name [lsort -dictionary [array names required_switches]] {
        puts stderr "Missing required switch  --${name}"
        set display_help 1
    }
    if {[array size required_switches]} { puts stderr "\n" }

    # Generate help text if needed
    if {$display_help} {
        puts stderr "${description}\n"
        if {[llength $all_flags]} {
            puts stderr "Flags:\n"
            foreach {flag help} $all_flags { puts stderr [format { -%-12s%s} $flag $help]\n }
            puts stderr "\n"
        }

        if {[llength $all_switches]} {
            puts stderr "Switches:\n"
            foreach {sw help def} $all_switches {
                if {$def eq "-"} {
                    set opt "(Required)"
                } elseif {$def eq ""} {
                    set opt "(Optional)"
                } else {
                    set opt "(Default: $def)"
                }
                puts stderr [format { --%-24s%s %s} $sw $opt $help]\n
            }
            puts stderr "\n"
        }
        exit
    }

    # Return the list of values not assigned to anything
    return $a
}


#---------------------------------------------------------------------------------------------------
# Terminal commands that manipulate stdout.
#
#   MISC
#
#   terminal initialize
#       Automatically called to initialize the internal state.  Can be called again to determine
#       whether the console supports special output (return value = 1).
#
#   POSITIONING
#
#   terminal setpos <row> <column>
#       Sets the current cursor position to a defined <row> <column> location
#   terminal savepos
#       Saves the current cursor position so it can be loaded later
#   terminal loadpos
#       Moves the cursor to the last saved cursor position
#   terminal up <lines>
#       Move the cursor up by <rows> rows
#   terminal down <lines>
#       Move the cursor down by <rows> rows
#   terminal left <columns>
#       Move the cursor left by <columns> columns
#   terminal right <columns>
#       Move the cursor right by <columns> columns
#   terminal home
#       Move the cursor to the start of the line
#
#   ERASING OUTPUT
#
#   terminal cls
#       Erases all text on the screen and resets the cursor position to (0,0)
#   terminal clearline
#       Erases text from the current cursor position to the end of the line
#
#   TEXT EFFECTS
#       All effects below last until the next 'terminal reset'
#
#   terminal color <color>
#       Changes the foreground color of text to one of:
#           black red green yellow blue magenta cyan white default
#   terminal bgcolor <color>
#       Changes the background color of text to one of:
#           black red green yellow blue magenta cyan white default
#   terminal emphasis
#   terminal dim
#   terminal underline
#   terminal flash
#   terminal reverse
#   terminal invisible
#   terminal reset
#
#  STRING OUTPUT
#
#   terminal write <string> ?<arg 0>? ?<arg 1>? ...
#       Allows the rest of the commands to be accessed in text strings via markup.  Based on an
#       implementation from http://wiki.tcl.tk/37261.
#
#       POSITIONING
#           <tpos> : terminal setpos @ @ (where @ @ are the next two arguments to 'terminal write')
#           <tsp>  : terminal savepos
#           <tlp>  : terminal loadpos
#           <tu>   : terminal up @ (where @ is the next argument to 'terminal write')
#           <td>   : terminal down @ (where @ is the next argument to 'terminal write')
#           <tl>   : terminal left @ (where @ is the next argument to 'terminal write')
#           <tr>   : terminal right @ (where @ is the next argument to 'terminal write')
#           <th>   : terminal home
#
#       ERASING OUTPUT
#           <cls> : terminal cls
#           <clr> : terminal clear line ("row")
#
#       TEXT EFFECTS
#           <e> : terminal emphasis
#           <d> : terminal dim
#           <u> : terminal underline
#           <f> : terminal flash
#           <v> : terminal reVerse
#           <i> : terminal invisible
#           </> : terminal reset
#
#           <k> : terminal color black
#           <r> : terminal color red
#           <g> : terminal color green
#           <y> : terminal color yellow
#           <b> : terminal color blue
#           <m> : terminal color magenta
#           <c> : terminal color cyan
#           <w> : terminal color white
#           <d> : terminal color default
#
#           <kb> : terminal bgcolor black
#           <rb> : terminal bgcolor red
#           <gb> : terminal bgcolor green
#           <yb> : terminal bgcolor yellow
#           <bb> : terminal bgcolor blue
#           <mb> : terminal bgcolor magenta
#           <cb> : terminal bgcolor cyan
#           <wb> : terminal bgcolor white
#           <db> : terminal bgcolor default
#
#
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc terminal {args} {
    set args [lassign $args command]
    if {[catch { eval ::_tcltools::terminal::${command} $args } msg]} {
        if {"" eq [info proc ::_tcltools::terminal::${command}]} {
            error "'$command' is not a valid terminal instruction"
        } else {
            error "Error in 'terminal $command': $msg"
        }
    }
}

namespace eval ::_tcltools::terminal {

    # Variables for tags replacement and escaping
    variable replacements
    variable escapes

    variable color_to_tag
    array set color_to_tag { black k red r green g yellow y blue b magenta m cyan c white w default d }
    variable bgcolor_to_tag
    array set bgcolor_to_tag { black kb red rb green gb yellow yb blue bb magenta mb cyan cb white wb default db }

    proc initialize {} {
        variable replacements
        variable escapes

        # Control sequence that leads into special output control characters
        set ctrl [binary format a2 \x1b\x5b]

        # Positioning
        array set tags {
            tpos     {"${ctrl}%s;%sf"}
            tsp      {"${ctrl}s"}
            tlp      {"${ctrl}u"}
            tu       {"${ctrl}%sA"}
            td       {"${ctrl}%sB"}
            tr       {"${ctrl}%sC"}
            tl       {"${ctrl}%sD"}
            th       {[binary format a1 \x0d]}
        }

        # Effects
        array set tags {
            e {[binary format a4 \x1b\x5b\x31\x6d]}
            d {[binary format a4 \x1b\x5b\x32\x6d]}
            u {[binary format a4 \x1b\x5b\x34\x6d]}
            f {[binary format a4 \x1b\x5b\x35\x6d]}
            v {[binary format a4 \x1b\x5b\x37\x6d]}
            i {[binary format a4 \x1b\x5b\x39\x6d]}
            / {[binary format a4 \x1b\x5b\x30\x6d]}
        }

        # Foreground Colors
        array set tags {
            k  {[binary format a5 \x1b\x5b\x33\x30\x6d]}
            r  {[binary format a5 \x1b\x5b\x33\x31\x6d]}
            g  {[binary format a5 \x1b\x5b\x33\x32\x6d]}
            y  {[binary format a5 \x1b\x5b\x33\x33\x6d]}
            b  {[binary format a5 \x1b\x5b\x33\x34\x6d]}
            m  {[binary format a5 \x1b\x5b\x33\x35\x6d]}
            c  {[binary format a5 \x1b\x5b\x33\x36\x6d]}
            w  {[binary format a5 \x1b\x5b\x33\x37\x6d]}
            d  {[binary format a5 \x1b\x5b\x33\x39\x6d]}
        }

        # Background Colors
        array set tags {
            kb {[binary format a5 \x1b\x5b\x34\x30\x6d]}
            rb {[binary format a5 \x1b\x5b\x34\x31\x6d]}
            gb {[binary format a5 \x1b\x5b\x34\x32\x6d]}
            yb {[binary format a5 \x1b\x5b\x34\x33\x6d]}
            bb {[binary format a5 \x1b\x5b\x34\x34\x6d]}
            mb {[binary format a5 \x1b\x5b\x34\x35\x6d]}
            cb {[binary format a5 \x1b\x5b\x34\x36\x6d]}
            wb {[binary format a5 \x1b\x5b\x34\x37\x6d]}
            db {[binary format a5 \x1b\x5b\x34\x39\x6d]}
        }

        # Clear Output
        array set tags {
            clr      {"${ctrl}K"}
            cls      {"${ctrl}2J${ctrl}0;0f"}
        }

        # Make sure the namespace variables are reset
        set replacements [list]
        set escapes [list]

        # If the 'tput' program does not exist or the shell does not seem to support colors,
        # make all of the tags translate to empty strings.
        set supports_colors 1
        if {![file exists "/usr/bin/tput"] || [catch {exec /usr/bin/tput setaf 1}]} {
            foreach {k v} [array get tags] { set tags($k) {{}} }
            set supports_colors 0
        }

        foreach {tag replacement} [array get tags] {
            lappend escapes "<<$tag>" "<$tag>"
            lappend replacements "<$tag>" [expr $replacement]
        }

        return $supports_colors
    }

    proc write {msg args} {
        variable escapes
        variable replacements

        # Escape tags
        regsub -all -- "<<" $msg "<< " msg

        # Escape %'s to %%
        regsub -all -- "%" $msg "%%" msg

        # Replace tags with color codes
        set msg [string map $replacements $msg]

        # Re-establish escaped tags
        regsub -all "<< " $msg "<<" msg

        # Un-escape tags
        set msg [string map $escapes $msg]

        # Pass arguments to formatted tags (such as 'tpos') and unescape %% back into %
        set msg [eval format [list $msg] $args]

        # Print the resulting message to the console
        puts -nonewline stdout $msg
    }

    # Provide access to each of the tags through defined commands
    proc setpos {row column}    { terminal write "tpos" $row $column }
    proc savepos {}             { terminal write "" }
    proc loadpos {}             { terminal write "" }
    proc up {rows}              { terminal write "<tu>" $rows }
    proc down {rows}            { terminal write "<td>" $rows }
    proc left {columns}         { terminal write "<tl>" $columns }
    proc right {columns}        { terminal write "<tr>" $columns }
    proc home {}                { terminal write "<th>" }
    proc cls {}                 { terminal write "<cls>" }
    proc clearline {}           { terminal write "<clr>" }
    proc emphasis {}            { terminal write "<e>" }
    proc dim {}                 { terminal write "<d>" }
    proc underline {}           { terminal write "<u>" }
    proc flash {}               { terminal write "<f>" }
    proc reverse {}             { terminal write "<v>" }
    proc invisible {}           { terminal write "<i>" }
    proc reset {}               { terminal write "</>" }
    proc color {name} {
        variable color_to_tag
        if {[catch {terminal write "<$color_to_tag($name)>"}]} { error "not a color: $name" }
    }
    proc bgcolor {color} {
        variable bgcolor_to_tag
        if {[catch {terminal write "<$bgcolor_to_tag($name)>"}]} { error "not a color: $name" }
    }

    # invoke initialization routine
    initialize
}

#------------------------------------------------------------------------------- 
# Helper methods to print output to the given pipe, or exit the program if there
# is an error.  This is helpful for programs that stream data from input to
# stdout and want to cleanly avoid the 'broken pipe' error.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc puts_x {pipe msg}           { if {[catch { puts $pipe $msg }]} { exit 0 } }
proc puts_x_nonewline {pipe msg} { if {[catch { puts -nonewline $pipe $msg }]} { exit 0 } }
