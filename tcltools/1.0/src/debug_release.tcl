################################################################################
#
# Two @ procedures are declared which allow code to be conditionally executed
# in debug or release mode.  See package.tcl for how to toggle the modes.
#
# @debug and @release can be used in the same 3 ways:
#
#   1. conditionally execute a block of code
#
#       @debug {
#           ...
#       }
#
#   2. conditionally execute a line of code
#
#       @debug proc foo {args} { ...}
#
#   3. return 1 or 0 depending on the state
#
#       call_foo [@debug]
#
# Authors:
#   Karl Gluck
#
#------------------------------------------------------------------------------- 

@proc debug {args} {
    set arglen [llength $args]
    if {$arglen == 0} {
        return 1 ; # 0 will be returned if the proc is @off
    } elseif {$arglen == 1} {
        set code [catch {uplevel 1 [lindex $args 0]} res]
    } else {
        set code [catch {uplevel 1 [concat $args]} res]
    }
    if {$code == 0} { return 1 } else { return -code $code $res }
}

@proc release {args} {
    set arglen [llength $args]
    if {$arglen == 0} {
        return 1 ; # 0 will be returned if the proc is @off
    } elseif {$arglen == 1} {
        set code [catch {uplevel 1 [lindex $args 0]} res]
    } else {
        set code [catch {uplevel 1 [concat $args]} res]
    }
    if {$code == 0} { return 1 } else { return -code $code $res }
}

