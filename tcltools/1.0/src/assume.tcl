####################################################################################################
# 
# @assume allows non-obvious, non-testable or potentionally problematic assumptions to be documented
# in executing code.  This can help with debugging because assumptions that are encountered during
# program execution will be logged.
#
# To get assumptions, somewhere in the client project put a command like this:
#
#   @on assume
#   @on assume.callback
#   @proc assume.callback {count caller phrase} {
#       # this will be called after the top function in the call stack containing a call
#       # to @assume has returned
#       puts [format {%-5s %30s %s} $count $caller $phrase]
#   }
#
# Because of how the @assume function works, it is best to contain your entire application within
# a single "main" function that only returns when the application exits, and exits only by
# returning (rather than via 'exit' or similar mechanisms).
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
namespace eval  tcltools {}
namespace eval _tcltools {}

@proc assume {phrase} { 
    set caller [lindex [info level 1] 0]
    set phrase_sub [regsub -all {[^A-Za-z0-9_]} $code "_"]e
    set var "::_tcltools::__assume_{$caller}{$phrase_sub}"
    if {[info exists $var]} {
        incr $var
    } else {
        set $var 1
        lappend {::_tcltools::assume.assumptions} $caller $phrase $var
    }
    once {
        on_final_return {
            set assumptions [list]
            foreach {caller phrase var} ${::_tcltools::assume.assumptions} {
                lappend assumptions [list [set $var] $caller $phrase]
            }
            set assumptions [lsort -index 0 -integer -increasing -- $assumptions]
            foreach data $assumptions {
                lassign $assumptions count caller phrase
                @assume.callback $count $caller $phrase
            }
        }
    }
}

# Don't enable 'assume' logging unless specifically requested
@off assume
@off assume.callback

