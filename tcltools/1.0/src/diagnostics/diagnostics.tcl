####################################################################################################
#
#  Defines a testing framework for TclTools.  This framework can be accessed by asking for the
#  package "tcltools.diagnostics".  The functionality it provides is based on the Jasmine library
#  for JavaScript.
#
#  @describe "thing" { <code> }
#   Can have other descriptions in it, or functionality descriptions.
#
#  it "performs some function" { <code> }
#   A description of some functionality that is being performed.  Contains expectations.  This
#   is evaluated in the context of a 'describe'
#
#  beforeEach { <code> }
#   Evaluates some code before every "it" in an @describe block
#
#  afterEach { <code> }
#   Evaluates some code after every "it" in an @describe block
#
#  expect {expression} to < be undefined|be defined|be truthy|be falsy|be less than <value>
#                          |be greater than <value>|match {regex}|contain <list_item> >
#   Declares an expectation that a certain expression evaluates.  If an expectation is not met,
#   execution continues as normal (it does not abort).
#
#  Authors:
#    Karl Gluck
#
#---------------------------------------------------------------------------------------------------
namespace eval tcltools {}
namespace eval _tcltools {}

namespace eval tcltools::diagnostics {
    variable results [list]
}
namespace eval ::_tcltools::diagnostics {}

#---------------------------------------------------------------------------------------------------
# Returns a testing report suitable for console output.  There are special control characters added
# to color the console output to make the reports more legible.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::tcltools::diagnostics::console_report {} {
    set retval {}

    set retval_colored [list]
    set red   [binary format a5 \x1b\x5b\x33\x31\x6d]
    set green [binary format a5 \x1b\x5b\x33\x32\x6d]
    set bold [binary format a4 \x1b\x5b\x31\x6d]
    set underline [binary format a4 \x1b\x5b\x34\x6d]
    set title ${bold}${underline}
    set reset [binary format a4 \x1b\x5b\x30\x6d]

    set last_script {}
    set total_failures 0
    set total_passes 0

    foreach {script item} $::tcltools::diagnostics::results {
        set failures 0
        set passes 0
        set description [::_tcltools::diagnostics::report.describe $item 0]
        incr total_failures $failures
        incr total_passes $passes

        set colored_description [list]

        # If the script changes, add a new title
        if {$script ne $last_script} {
            lappend colored_description "" " ${title}${script}${reset}" ""
            set last_script $script
        }

        # Add each @describe line to the list, coloring each line according to
        # whether or not there was an error
        foreach line [split $description \n] {
            if {[string index $line 0] eq "*"} { set line ${bold}[string range ${line} 1 end] }
            if {[string match "*ERROR*" $line]} {
                lappend colored_description " ${red}${line}${reset}"
            } else {
                lappend colored_description " ${green}${line}${reset}"
            }
        }

        # Print a summary of this top-level @describe block
        lappend colored_description \
            {} \
            "         ${passes} passed / [expr {$failures > 0 ? ${red} : ${reset}}]${failures} failed${reset} ([format %.02f%% [expr {100.0 * $passes / ($passes + $failures)}]])"

        append retval [join $colored_description \n]\n\n
        
    }

    # Create a tag to place at the start and end of the output.  This declares the status
    # of the test suite overall.
    set boundary [string repeat # 100]
    if {$total_failures > 0} {
        set tag ${red}
        set results [format {#%-98s#} "[string repeat { } 40]$total_failures TESTS FAILED"]
    } else {
        set tag ${green}
        set results [format {#%-98s#} "[string repeat { } 40]ALL $total_passes TESTS PASSED"]
    }
    set blank "#[string repeat { } 98]#"
    append tag [join [list $boundary $blank $results $blank $boundary] \n]
    append tag $reset


    return "${tag}\n\n${retval}\n\n${tag}"
}

#---------------------------------------------------------------------------------------------------
# Returns a string with the state of the given 'describe' item.  This can call itself recursively,
# since '@describe' can contain other '@describe' elements.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::_tcltools::diagnostics::report.describe {item indentation} {
    upvar passes passes
    upvar failures failures
    lassign $item description contents
    set description "[string repeat {  } $indentation]${description}"
    set starting_failures $failures

    set details {}
    incr indentation
    foreach {subtype subitem} $contents {
        if {$subtype eq "describe"} {
            append details [::_tcltools::diagnostics::report.describe $subitem $indentation]
        } elseif {$subtype eq "it"} {
            append details [::_tcltools::diagnostics::report.it $subitem $indentation]
        } else {
            error "unknown subtype: $subtype"
        }
    }
    incr indentation -1

    set retval ""
    set new_failures [expr {$failures - $starting_failures}]
    if {$new_failures > 0} {
        append retval [format {%-80s %4s ERROR%s} $description $new_failures [expr {$new_failures != 1 ? "S" : ""}]]
    } else {
        append retval [format {%-85s PASS} $description]
    }
    append retval \n$details

    return $retval
}

#---------------------------------------------------------------------------------------------------
# Returns a string indicating the test state of the given 'it' item.  This sums the states of all
# of the child 'expect' statements.  If any is an error, all sub-states are printed.  If all pass,
# none of the sub-states are printed and only a single 'PASS' line is emitted.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::_tcltools::diagnostics::report.it {item indentation} {
    upvar passes passes
    upvar failures failures
    set retval [list]
    set details [list]
    set starting_failures $failures
    lassign $item description contents
    set description "[string repeat {  } $indentation]$description"
    incr indentation
    foreach subitem $contents {
        append details [::_tcltools::diagnostics::report.expect $subitem $indentation]
    }
    incr indentation -1
    set new_failures [expr {$failures - $starting_failures}]
    if {$new_failures > 0} {
        # There were one or more failures.  Report all of the expectations.
        set retval [format {%-80s %4s ERROR%s} $description $new_failures [expr {$new_failures != 1 ? "S" : ""}]]
        append retval \n$details
    } else {
        # There were no failures in this 'it', so just report the 'passing' line.
        set retval [format {%-85s PASS} $description]\n
    }
    return $retval
}

#---------------------------------------------------------------------------------------------------
# Returns a string indicating the pass/fail for a single expectation.  This string will only be
# displayed if there are 1 or more fails within the 'it'.  The 'passes' or 'failures' shared
# variables will be incremented according to the result.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::_tcltools::diagnostics::report.expect {item indentation} {
    upvar passes passes
    upvar failures failures
    lassign $item ok msg 
    set msg "[string repeat {  } $indentation]$msg"
    if {$ok} {
        incr passes
        return [format {%-85s PASS} $msg]\n
    } else {
        incr failures
        # prepend the actual errors with a * so they get highlighted
        return [format {*%-85s ERROR} $msg]\n
    }
}

#---------------------------------------------------------------------------------------------------
# Defines an object that needs testing.  The @describe function is only enabled if "@on describe"
# is set before this file is included.
# 
# Other testing functions are defined only within the context of the @describe and will not
# clobber functions with the same names.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
@proc describe {__thing __code} {
    set __is_outermost [expr {[info level] == 1}]

    # Make sure this is a valid call to @describe
    if {!$__is_outermost} {
        if {[lindex [info level [expr {[info level] - 1}]] 0] ne "@describe"} {
            error "@describe can only be called from script root, or within another @describe"
        }
    }

    # Setup
    if {$__is_outermost} {

        # this is the outermost 'thing'
        foreach cmd { it beforeEach afterEach expect } {
            set saved "__tcltools_saved__${cmd}"
            if {[info proc $cmd] ne ""} { rename $cmd $saved }
        }

        namespace eval :: {
            proc it {__functionality code} {
                upvar __before_each before_each
                if {[info exists before_each]} { uplevel 1 $before_each }

                upvar __it_retval __it_retval
                set __it_retval [list]

                uplevel 1 $code

                upvar __describe_retval __describe_retval
                lappend __describe_retval "it" [list ${__functionality} ${__it_retval}]

                upvar __after_each after_each
                if {[info exists after_each]} { uplevel 1 $after_each }
            }

            proc beforeEach {code} {
                upvar __before_each before_each
                set before_each $code
            }

            proc afterEach {code} {
                upvar __after_each after_each
                set after_each $code
            }

            proc expect {expression args} {

                if {[catch {
                    switch -glob -- $args {
                    "to be undefined"       { set ok [expr {![uplevel 1 [format {info exists %s} $expression]]}] }
                    "to be defined"         { set ok [uplevel 1 [format {info exists %s} $expression]] }
                    "to throw an error"     { set ok [expr {1==[catch {uplevel 1 $expression}]}] }
                    "to be truthy"          { set ok [uplevel 1 [format {expr {(%s)?1:0}} $expression]] }
                    "to be falsy"           { set ok [uplevel 1 [format {expr {(%s)?0:1}} $expression]] }
                    "to be equal to *"      { set ok [uplevel 1 [format {expr {(%s)==({%s})}} $expression [lindex $args end]]] }
                    "to be less than *"     { set ok [uplevel 1 [format {expr {(%s)<({%s})}} $expression [lindex $args end]]] }
                    "to be greater than *"  { set ok [uplevel 1 [format {expr {(%s)>({%s})}} $expression [lindex $args end]]] }
                    "to match *"            { set ok [uplevel 1 [format {regexp {%s} %s} [lindex $args end] $expression]] }
                    "to not contain *"      { set ok [uplevel 1 [format {expr {0>[lsearch -exact %s {%s}]}} $expression [lindex $args end]]] }
                    "to contain *"          { set ok [uplevel 1 [format {expr {0<=[lsearch -exact %s {%s}]}} $expression [lindex $args end]]] }
                    default                 { error "unrecognized 'expect' type" }
                    }
                    if {!$ok} {
                        switch -glob -- $args {
                        "to be undefined"       { error "{$expression} was expected to be undefined" }
                        "to be defined"         { error "{$expression} was expected to be defined" }
                        "to throw an error"     { error "{$expression} didn't throw an error" }
                        "to be truthy"          { error "{$expression} was not truthy" }
                        "to be falsy"           { error "{$expression} was not falsy" }
                        "to be equal to *"      { error "{$expression} was not equal to {[lindex $args end]}" }
                        "to be less than *"     { error "{$expression} was not less than {[lindex $args end]}" }
                        "to be greater than *"  { error "{$expression} was not greater than {[lindex $args end]}" }
                        "to match *"            { error "{$expression} didn't match {[lindex $args end]}" }
                        "to not contain *"      { error "{$expression} was not supposed to contain {[lindex $args end]}" }
                        "to contain *"          { error "{$expression} didn't contain element {[lindex $args end]}" }
                        }
                    }
                } msg]} {
                    set ok 0
                    set msg [string map {\n { }} $msg]
                } else {
                    # make the success message 
                    switch -glob -- $args {
                    "to be undefined"       { set msg "{$expression} was undefined" }
                    "to be defined"         { set msg "{$expression} was defined" }
                    "to throw an error"     { set msg "{$expression} threw an error" }
                    "to be truthy"          { set msg "{$expression} was truthy" }
                    "to be falsy"           { set msg "{$expression} was falsy" }
                    "to be equal to *"      { set msg "{$expression} was equal to {[lindex $args end]}" }
                    "to be less than *"     { set msg "{$expression} was less than {[lindex $args end]}" }
                    "to be greater than *"  { set msg "{$expression} was greater than {[lindex $args end]}" }
                    "to match *"            { set msg "{$expression} matched {[lindex $args end]}" }
                    "to not contain *"      { set msg "{$expression} did not contain {[lindex $args end]}" }
                    "to contain *"          { set msg "{$expression} contained element {[lindex $args end]}" }
                    }
                }

                upvar __it_retval __it_retval
                lappend __it_retval [list $ok $msg]
            }
        }
    }

    # Execute code to evaluate the definitions
    set __describe_retval [list]
    set __catch_code [catch $__code __msg]
    # should have stuff in __describe_retval now

    # Teardown
    if {$__is_outermost} {
        # this was the outermost 'thing'
        foreach cmd { it beforeEach afterEach expect } {
            set saved "__tcltools_saved__${cmd}"
            rename $cmd {} ; # remove our new declaration
            if {[info proc $saved ] ne ""} { rename $saved $cmd }
        }
    }

    # Return any syntax/execution issues
    if {$__catch_code} {
        return -code $__catch_code $__msg
    }

    # Outermost?  Add results to global context.  Not? Append them to caller!
    if {$__is_outermost} {
        lappend ::tcltools::diagnostics::results [info script] [list ${__thing} ${__describe_retval}]
    } else {
        upvar __describe_retval __upper_describe_retval
        lappend __upper_describe_retval "describe" [list ${__thing} ${__describe_retval}]
    }
} 

#---------------------------------------------------------------------------------------------------
# Pushes something new on to the description stack
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::tcltools::diagnostics::begin_defining_thing {thing} {
    lappend describe_stack $thing
    return [expr {[llength $describe_stack] == 1}]
}

#---------------------------------------------------------------------------------------------------
# Pops the last thing from the description stack
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::tcltools::diagnostics::end_defining_thing {thing} {
    set describe_stack [lrange describe_stack 0 end-1]
    return [expr {[llength $describe_stack] == 0}]
}

#---------------------------------------------------------------------------------------------------
# Returns the current object being described
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::tcltools::diagnostics::current_thing {} {
    return [join $describe_stack " :: "]
}
