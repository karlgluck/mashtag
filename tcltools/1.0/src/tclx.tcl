####################################################################################################
#
#  TCL language extensions that add new features, control structures, etc.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
namespace eval tcltools {}
namespace eval _tcltools {}


#---------------------------------------------------------------------------------------------------
# The 'forsearch' construct allows you to express a common functional idea:  look through each
# element in a list until an element meeting some requirements is found, then break.  If no element
# is found, execute some code.
#
# Example:
#
#   forsearch line $lines {
#       if {[regexp $RE $line]} { break }
#   } else {
#       # no line matched the regex
#   }
#
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc forsearch {args} {
    set else_code    [lindex $args end]
    set else_literal [lindex $args end-1]
    set body_code    [lindex $args end-2]
    set args [lrange $args 0 end-3]

    set code [catch {
        uplevel 1 [set xcode [format {
            foreach %s {
                switch -exact -- [catch {%s} __forsearch_msg] {
                0 {
                    # end of loop
                }
                1 {
                    # exception
                    error ${__forsearch_msg}
                }
                2 {
                    # return
                    return -code return [list 1 ${__forsearch_msg}]
                }
                3 {
                    # code exited with a break
                    return -code return [list 0 0]
                }
                4 {
                    # continue
                }
                }
                unset __forsearch_msg
            }
            # code did not execute a break
            return -code return [list 0 1]
        } $args $body_code]]
    } msg]

    if {$code == 2} {
        lassign $msg type value
        if {$type} {
            # there was a 'return' inside the body
            return -code 2 $value
        } else {
            # Normal termination of the foreach loop
            if {$value} {
                # The loop didn't "break" out
                set code [catch {uplevel 1 $else_code} msg]
                return -code $code $msg
            }
        }
    } else {
        return -code $code $msg
    }
}

@describe "forsearch" {
    it "provides access to local variables in the body" {
        set local_var "old value"
        forsearch num [list 1 2 3] {
            set local_var "new value"
        } else { }
        expect {$local_var} to be equal to "new value"
    }
    it "forwards 'return' statements from the body" {
        set code [catch {
            forsearch num [list 1 2 3] {
                return "hello"
            } else {
            }
        } msg]
        expect {$code} to be equal to 2
        expect {$msg} to be equal to "hello"
    }
    it "forwards 'error' calls from the body" {
        set code [catch {
            forsearch num [list 1 2 3] {
                error "hello"
            } else {
            }
        } msg]
        expect {$code} to be equal to 1
        expect {$msg} to be equal to "hello"
    }
    it "executes 'else' when no break is encountered" {
        forsearch num [list 1 2 3] {
        } else {
            set set_by_else 1
        }
        expect {set_by_else} to be defined
    }
    it "provides access to local variables in the else clause" {
        set local_var "old value"
        forsearch num [list 1 2 3] {
        } else {
            set local_var "new value"
        }
        expect {$local_var} to be equal to "new value"
    }
    it "forwards 'return' statements from the else clause" {
        set code [catch {
            forsearch num [list 1 2 3] {
            } else {
                return "hello"
            }
        } msg]
        expect {$code} to be equal to 2
        expect {$msg} to be equal to "hello"
    }
    it "forwards 'error' calls from the else clause" {
        set code [catch {
            forsearch num [list 1 2 3] {
            } else {
                error "hello"
            }
        } msg]
        expect {$code} to be equal to 1
        expect {$msg} to be equal to "hello"
    }
    it "forwards 'continue' statements from the else clause" {
        set code [catch {
            forsearch num [list 1 2 3] {
            } else {
                continue
            } 
        } msg]
        expect {$code} to be equal to 4
    }
    it "forwards 'break' statements from the else clause" {
        set code [catch {
            forsearch num [list 1 2 3] {
            } else {
                break
            }
        } msg]
        expect {$code} to be equal to 3
    }
    
}

#---------------------------------------------------------------------------------------------------
# Finds the closest variable called $name in the call-stack and brings it
# into the caller's context.  The second parameter is what to alias the
# variable to; if not defined, it will use the first parameter's value
# by default.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc upvar_closest {name {as {}}} {
    if {$as eq {}} { set as $name }
    set my_level [info level]
    set level 0
    while {$level < $my_level} {
        incr level
        upvar $level $name var
        if {[info exists var]} {
            incr level -1
            uplevel 1 "upvar $level $name $as"
            return
        }
    }
    uplevel 1 "unset -nocomplain $as"
}


#---------------------------------------------------------------------------------------------------
# Saves the entire program state into a string that can be evaluated by the Tcl interpreter to
# restore the program's global state.  This lets you save an entire program to disk and load it
# back later, or fork a thread with duplicated global state.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc interpreter_state {} {
    set code [list]
    foreach ns [concat {{}} [_interpreter_state.namespaces]] {
        lappend code "namespace eval {$ns} {}"
        foreach var [info vars ${ns}::*] {
            if {[array exists $var]} {
                lappend code "array set {$var} {[array get $var]}"
            } elseif {[info exists $var]} {
                lappend code "set {$var} {[set $var]}"
            }
            # else { some variables are listed but don't exist! Found in Tk. }
        }
        foreach procname [info procs ${ns}::*] {
            lappend code [_interpreter_state.proc_to_script $procname]
        }
    }
    return [join $code \n]
}

proc _interpreter_state.proc_to_script {procname} {
    set result [list proc $procname]
    set args {}
    foreach arg [info args $procname] {
        if {[info default $procname $arg value]} {
            lappend args [list $arg $value]
        } else {
            lappend args $arg
        }
    }
    lappend result [list $args]
    lappend result [list [info body $procname]]
    return [join $result]
}

proc _interpreter_state.namespaces {{parent ::}} {
    set result [list]
    foreach ns [namespace children $parent] {
        lappend result {*}[_interpreter_state.namespaces $ns] $ns
    }
    return $result
}


#---------------------------------------------------------------------------------------------------
# Schedules a piece of code to be run when the top-level function in the call stack returns.
#
# For complex programs with a 'main' function, this is effectively when the program terminates as
# long as termination is not done by killing the interpreter (i.e. it won't trigger if 'exit' is
# used).
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc on_final_return {code} {
    set name "__watch_${::env(USER)}.[pid].[info level].[clock clicks]"

    # find the top-level function in call-stack
    set body {
        set {@name} {}
        trace add variable {@name} unset { @code ;#}
    }
    set body [regsub -all @name $body $name]
    set body [regsub -all @code $body $code]
    uplevel [expr {[info level]-1}] $body
}

#---------------------------------------------------------------------------------------------------
# Declares a static variable
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc static {name {value 0}} {
    set caller [lindex [info level -1] 0]
    set qname ::_tcltools::static::${caller}
    if {![info exists ${qname}::$name]} {
        foreach var [list [lrange [info level 0] 1 end]] {  
            if {[llength $var] == 1} { lappend var $value }
            namespace eval $qname [linsert $var 0 variable]
        }
    }
    uplevel 1 [list upvar 0 ${qname}::$name $name]
}

#---------------------------------------------------------------------------------------------------
# Executes the given code exactly once.
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc once {code} {
    set sentinel_code [regsub -all {[^A-Za-z0-9_]} $code "_"]
    set sentinel "::_tcltools::__once_sentinel_{[lindex [info level 1] 0]}{$sentinel_code}"
    set body {
        if {![info exists {@name}]} {
            set {@name} 1
            @code
        }
    }
    if {![info exists $sentinel]} {
        set $sentinel 1
        uplevel 1 $code
    }
}

@describe "once" {
    proc __tmp_describe_incr_once {} {
        once { upvar set_by_once var ; incr var 1 }
    }
    it "runs code the first time" {
        set set_by_once 1
        __tmp_describe_incr_once
        expect {$set_by_once} to be equal to 2
    }
    it "does not run code the second time" {
        __tmp_describe_incr_once
        expect {$set_by_once} to be equal to 2
    }
}

#---------------------------------------------------------------------------------------------------
# Returns a number that is guaranteed to be unique every time it is called
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc unique_key  {}  {
  global __uniqe_key__

  if {![info exists __uniqe_key__]} {
    set clicks [clock clicks]
    if {$clicks<0} {set clicks [expr -1 * $clicks]}
    set clicks [format "%012s" $clicks]
    set a [scan [string range $clicks 0 5] %d]
    set b [scan [string range $clicks 6 11] %d]
    set __uniqe_key__ [list $a $b]
    set t [clock clicks -milliseconds]
    return "$t[format "%09s%09s" $a $b]"
  }

  set max 999999999 ;# 10^10
  lassign $__uniqe_key__ a b
  if {$b<$max} {
    incr b
  } elseif {$a<$max} {
    set b 0
    incr a
  } else {
    error "Out of unique keys"
  }
  set __uniqe_key__ [list $a $b]
  set u [format "%09s%09s" $a $b]
  set t [clock clicks -milliseconds]
  return $t$u
}

#-------------------------------------------------------------------------------
# Puts a number into base62 format
#
#  Authors:
#    Karl Gluck
#-------------------------------------------------------------------------------
proc base62 {number} {
    if {$number == 0} { return "0" }
    if {$number < 0} { return "-[base62 [expr {abs(number)}]]" }

    array set char2num {}
    array set num2char {}
    for {set i 0} {$i < 10} {incr i} {
        set char2num($i) $i
    }
    for {set i 0} {$i < 26} {incr i} {
        # Capitals
        set char2num([format %c [expr {65+$i}]]) [expr {10+$i}]
        # Lowercase
        set char2num([format %c [expr {97+$i}]]) [expr {10+26+$i}]
    }

    foreach {k v} [array get char2num] {
        set num2char($v) $k
    }

    # translate number to characters
    set place 0
    set str ""
    while {$number > 0} {
        set digit [expr {$number % [array size num2char]}]
        set str "$num2char(${digit})${str}"
        set number [expr {$number / [array size num2char]}]
    }

    return $str
}

