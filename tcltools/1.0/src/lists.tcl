####################################################################################################
# 
# Contains functions for manipulating lists.  Most functions start with "l"
# for easy reference.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------
# Concatenates a list of values on to a list variable.
#
# $ set list_var [list "1" "2" "3"]
# $ lvarcat list_var [list "a" "b" "c"]
# $ puts $list_var
# 1 2 3 a b c
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lvarcat {lvar values} {
    upvar $lvar l
    set l [concat $l $values]
}

@describe "lvarcat" {
    it "appends values to a list" {
        set list_var [list "1" "2" "3"]
        lvarcat list_var [list "a" "b" "c"]
        expect {$list_var} to contain "a"
        expect {$list_var} to contain "b"
        expect {$list_var} to contain "c"
    }
}


#---------------------------------------------------------------------------------------------------
# Pushes an element to the end of a list.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lvarpush {lvar val} {
    upvar $lvar l
    set l [concat [list $val] $l]
}

#---------------------------------------------------------------------------------------------------
# Pops an element from the end of a list.  If the 'dest' parameter is set,
# this function returns 0 if the list was empty and 1 otherwise, and sets the
# variable named $dest to the value popped from the list.  If the 'dest'
# parameter is not set, this function returns the element it would have popped.
# If the list is empty, it returns an empty value.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lvarpop {lvar {dest {}}} {
    upvar $lvar l
    if {[string length $dest]} {
        if {[llength $l]} {
            upvar $dest out
            set l [lassign $l out]
            return 1
        } else {
            return 0
        }
    } else {
        set l [lassign $l retval]
        return $retval
    }
}

#---------------------------------------------------------------------------------------------------
# Returns the element at the top of a list-stack.  Essentially does 'lvarpop'
# without removing the element.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lvartop {lvar {dest {}}} {
    upvar $lvar l
    if {[string length $dest]} {
        if {[llength $l]} {
            upvar $dest out
            set out [lindex $l 0]
            return 1
        } else {
            return 0
        }
    } else {
        return [lindex $l 0]
    }
}


@describe "stack operations" {
    @describe "lvarpush" {
        set list_var [list]
        it "adds a value to an empty list" {
            lvarpush list_var "a"
            expect {$list_var} to contain "a"
        }
        it "adds another value the list" {
            lvarpush list_var "b"
            expect {$list_var} to contain "b"
        }
        it "returns the list variable" {
            expect {[lvarpush list_var "c"] eq $list_var} to be truthy
        }
    }
    @describe "lvarpop" {
        it "removes a value from the list" {
            set list_var [list "a"]
            lvarpop list_var
            expect {$list_var} to not contain "a"
            expect {[llength $list_var]} to be equal to 0
        }
        it "removes the last pushed value" {
            set list_var [list "a" "b" "c"]
            lvarpush list_var "T"
            set value_popped [lvarpop list_var]
            expect {$value_popped} to match "T"
            expect {$list_var} to not contain "T"
        }
        it "does nothing when the list is empty" {
            set list_var [list]
            set value [lvarpop list_var]
            expect {$value} to be equal to ""
        }
        it "returns 0 when called with an output variable on an empty list" {
            set empty_list [list]
            expect {[lvarpop empty_list out]} to be equal to 0
        }
        it "returns 1 when called with an output variable on a populated list" {
            set populated_list [list "a" "b" "c"]
            expect {[lvarpop populated_list out]} to be equal to 1
        }
    }
    @describe "lvartop" {
        it "returns the last value pushed to a list" {
            set list_var [list "a"]
            lvarpush list_var "T"
            expect {[lvartop list_var]} to match "T"
        }
        it "returns 0 when called with an output variable on an empty list" {
            set empty_list [list]
            expect {[lvartop empty_list out]} to be equal to 0
        }
        it "returns 1 when called with an output variable on a populated list" {
            set populated_list [list "a" "b" "c"]
            expect {[lvartop populated_list out]} to be equal to 1
        }
    }
}

#---------------------------------------------------------------------------------------------------
# Returns the numerically smallest value among the elements of the list
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lmin {l} {
    set l [lassign $l retval]
    foreach v $l { set retval [expr {$v < $retval ? $v : $retval}] }
    return $retval
}

@describe "lmin" {
    it "returns the lowest value in a list" {
        expect {[lmin [list 5 2 3]]} to be equal to 2
        expect {[lmin [list -1 3.5 12e4]]} to be equal to -1
    }
}

#---------------------------------------------------------------------------------------------------
# Returns the numerically greatest value among the elements of the list
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lmax {l} {
    set l [lassign $l retval]
    foreach v $l { set retval [expr {$v > $retval ? $v : $retval}] }
    return $retval
}

@describe "lmax" {
    it "returns the greatest value in a list" {
        expect {[lmax [list 5 2 3]]} to be equal to 5
        expect {[lmax [list -1 3.5 12e4]]} to be equal to 12e4
    }
}

#---------------------------------------------------------------------------------------------------
# Returns the median of a list of numbers (integers or reals)
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lmedian {l} {
    if {![llength $l]} then { return {} }
    if {[string is integer -strict [lindex $l 0]]} {
        return [lindex [lsort -integer $l] [expr {int([llength $l]/2)}]]
    } else {
        return [lindex [lsort -real $l] [expr {int([llength $l]/2)}]]
    }
}

@describe "lmedian" {
    it "returns the median value in an unsorted list of integers" {
        expect {[lmedian [list 5 8 16 -5 -4 -3 0]]} to be equal to 0
    }
    it "returns the median value in an unsorted list of reals" {
        expect {[lmedian [list 5.0 11.3 0.0 -3.5 -0.4]]} to be equal to 0.0 
    }
    it "throws an error if reals show up in an integer list" {
        expect {[lmedian [list 2 5.0 6.0]]} to throw an error
    }
}


#---------------------------------------------------------------------------------------------------
# Returns the average of a list of numbers
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc laverage {l} {
    set sum [eval expr "1.0*[join $l +]"]
    return [expr {$sum / [llength $l]}]
}

#---------------------------------------------------------------------------------------------------
# Returns true if the list is empty (lempty) or true if the list has at least
# 1 element (lnotempty)
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lempty    {l} { return [expr {0 >= [llength $l]}] }
proc lnotempty {l} { return [expr {0 <  [llength $l]}] }

@describe "lempty" {
    it "correctly describes empty/populated lists" {
        expect {[lempty [list "a" "b" "c"]]} to be falsy
        expect {[lempty [list]]} to be truthy
    }
}

@describe "lnotempty" {
    it "correctly describes empty/populated lists" {
        expect {[lnotempty [list "a" "b" "c"]]} to be truthy
        expect {[lnotempty [list]]} to be falsy
    }
}

#---------------------------------------------------------------------------------------------------
# Returns the unique list entries from the given list.  Order is preserved.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lunique {l} {
    array set keys {}
    return [lprocess $l {e} {
        upvar keys keys
        if {[info exists keys($e)]} { return {} } else {
            set keys($e) {}
            return [list $e]
        }
    }]
}

@describe "lunique" {
    it "removes duplicate elements from a list" {
        set list_var [list "a" "b" "b" "c" "c" "c"]
        set list_var [lunique $list_var]
        expect {$list_var} to contain "a"
        expect {$list_var} to contain "b"
        expect {$list_var} to contain "c"
        expect {[llength $list_var]} to be equal to 3
    }
    it "preserves order" {
        set list_var [list "b" "a" "a" "c" "c" "c"]
        set list_var [lunique $list_var]
        expect {[lindex $list_var 0]} to match "b"
        expect {[lindex $list_var 1]} to match "a"
        expect {[lindex $list_var 2]} to match "c"
        expect {[llength $list_var]} to be equal to 3
    }
}


#---------------------------------------------------------------------------------------------------
# Reorders the first list so that any elements present in the second list 
# are in the same order as those in the second list, and any elements not
# present in the second list are moved to the end.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lreorder {l_to_sort l_with_order} {
    # sort the shared entries, append the unique entries
    lassign [intersect3 $l_to_sort $l_with_order] a b -
    return [concat [lsort -command _lreorder.sortcommand $b] $a]
}
proc _lreorder.sortcommand { a b } {
    upvar l_with_order l_with_order
    return [expr {[lsearch $l_with_order $a] - [lsearch $l_with_order $b]}]
}

@describe "lreorder" {
    set order [list "e" "a" "b" "d" "c"]

    it "changes the order of one list to match another" {
        set list_var [list "a" "b" "c" "d" "e"]
        expect {[lreorder $list_var $order] eq $order} to be truthy
    }
    it "doesn't mix in elements from the order list" {
        set list_var [list "a" "c" "b"]
        set reordered [lreorder $list_var $order]
        expect {[llength $reordered]} to be equal to 3
        expect {[llength $reordered]} to not contain "e"
        expect {[llength $reordered]} to not contain "d"
    }
    it "puts values that are ordered at the end" {
        set list_var [list "a" "c" "b" "X" "Y" "Z"]
        set reordered [lreorder $list_var $order]
        expect {[llength $reordered]} to be equal to 6
        expect {$reordered} to contain "X"
        expect {$reordered} to contain "Y"
        expect {$reordered} to contain "Z"
        expect {[lrange $reordered 0 2]} to not contain "X"
        expect {[lrange $reordered 0 2]} to not contain "Y"
        expect {[lrange $reordered 0 2]} to not contain "Z"
    }
}


#---------------------------------------------------------------------------------------------------
# Returns the intersection of two lists, preserving duplicates.  Thus:
#   [lintersect {a a b} {a a}]  == { a a }
#
# Order is not preserved.  If you want to preserve order, use lreorder on
# the output with one of the input lists.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lintersect {a b} {
    lassign [intersect3 $a $b] - s -
    return $s
}

@describe "lintersect" {
    it "returns the intersection of two lists" {
        set abcx [list "a" "b" "c" "x"]
        set xyzw [list "x" "y" "z" "w"]
        set intersection [lintersect $abcx $xyzw]
        expect {[llength $intersection]} to be equal to 1
        expect {$intersection} to contain "x"
    }
    it "preserves duplicates" {
      set abb [list "a" "b" "b"]
      set bbc [list "b" "b" "c"]
      set intersection [lintersect $abb $bbc]
      expect {[llength $intersection]} to be equal to 2
      expect {$intersection} to contain "b"
      expect {$intersection} to not contain "a"
      expect {$intersection} to not contain "c"
    }
}


#---------------------------------------------------------------------------------------------------
# Returns the subtraction of list B from list A; e.g.
#   [lsubtract {a a b c} {a b d}]  == { a c }
#
# Order is not preserved.  If you want to preserve order, use lreorder on
# the output with one of the input lists.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lsubtract {a b} {
    lassign [intersect3 $a $b] s - -
    return $s
}

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

#---------------------------------------------------------------------------------------------------
# Returns elements exclusive to the first list, the intersection,
# and elements exclusive to the second list--permitting duplicates.
#
# intersect3 {a a b 1 2 x} {a b b 1 2 y} 
#   {{a x} {1 2 a b} {b y}}

# Order is not preserved.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc intersect3 {a b} {
    set a [lsort $a]
    set b [lsort $b]
    lassign {} a_only shared b_only
    while {[llength $a] > 0 && [llength $b] > 0} {
        set an [lassign $a av]
        set bn [lassign $b bv]
        if {[string match $av $bv]} {
            lappend shared $av
        } else {
            set next_a_in_b [lsearch -ascii -sorted $bn $av]
            set next_b_in_a [lsearch -ascii -sorted $an $bv]
            if {$next_b_in_a >= 0 && ($next_b_in_a < $next_a_in_b || $next_a_in_b < 0)} {
                set a_only [concat $a_only [list $av] [lrange $an 0 [expr {$next_b_in_a-1}]]]
                set an [lrange $an $next_b_in_a end]
                set bn [concat [list $bv] $bn] 
            } elseif {$next_a_in_b >= 0 && ($next_a_in_b < $next_b_in_a || $next_b_in_a < 0)} {
                set b_only [concat $b_only [list $bv] [lrange $bn 0 [expr {$next_a_in_b-1}]]]
                set an [concat [list $av] $an] 
                set bn [lrange $bn $next_a_in_b end]
            } else {
                # one must not be -1 otherwise the lists aren't sorted
                if {$next_b_in_a != -1 || $next_a_in_b != -1} { error "intersect3 logic error" }
                set a_only [concat $a_only [list $av]]
                set b_only [concat $b_only [list $bv]]
                # neither front element exists and the front elements aren't
                # equal, so they will get popped off
            }
        }
        set a $an
        set b $bn
    }
    set a_only [concat $a_only $a]
    set b_only [concat $b_only $b]
    return [list $a_only $shared $b_only]
}


@describe "intersect3" {
    set abc [list "a" "b" "c"]
    set cde [list "c" "d" "e"]
    set abccd [list "a" "b" "c" "c" "d"]
    set cdeef [list "c" "d" "e" "e" "f"]
    it "handles empty lists" {
        expect {[intersect3 [list] [list]] eq [list [list] [list] [list]]} to be truthy
        expect {[intersect3 $abccd [list]] eq [list $abccd [list] [list]]} to be truthy
        expect {[intersect3 [list] $cdeef] eq [list [list] [list] $cdeef]} to be truthy
    }
    it "handles self-intersections" {
        expect {[intersect3 $abc $abc] eq [list [list] $abc [list]]} to be truthy
    }
    it "intersects lists with a simple common set" {
        lassign [intersect3 $abc $cde] first shared second
        expect {$first} to contain "a"
        expect {$first} to contain "b"
        expect {$first} to not contain "c"
        expect {[llength $first]} to be equal to 2
        expect {$shared} to contain "c"
        expect {[llength $shared]} to be equal to 1
        expect {$second} to not contain "c"
        expect {$second} to contain "d"
        expect {$second} to contain "e"
        expect {[llength $second]} to be equal to 2
    }
    it "intersects lists with a common set with repeated elements" {
        lassign [intersect3 $abccd $cdeef] first shared second
        expect {$first} to contain "a"
        expect {$first} to contain "b"
        expect {$first} to contain "c"
        expect {$first} to not contain "d"
        expect {[llength $first]} to be equal to 3
        expect {$shared} to contain "c"
        expect {$shared} to contain "d"
        expect {[llength $shared]} to be equal to 2
        expect {$second} to not contain "c"
        expect {$second} to not contain "d"
        expect {$second} to contain "e"
        expect {$second} to contain "f"
        expect {[llength $second]} to be equal to 3
        
    }
}



#---------------------------------------------------------------------------------------------------
# Invokes a function on sets of one or more elements in the list, mapping
# each set of parmeters to that number of consecutive elements in the list
# and invoking the code as if called in caller's scope.
#
# There are two ways to call this: by defining a new function (a lambda) or by
# invoking an existing procedure.  If a lambda is used, the syntax is:
#
#   lprocess $list {arg1 arg2 arg3...} {code...}
#
# If an existing function is used, the syntax is:
#
#   lprocess $list function_name
#
# A new list is built from the returned values of the code.  Values are concatenated
# to the list being returned, so a return value of {} will add nothing to the
# output and effectively act as a filter.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc lprocess {listin args} {
    switch [llength $args] {
    1 {
        lassign $args proc_name
        return [_lprocess.func 2 $listin $proc_name]
    }
    2 {
        lassign $args params code
        return [_lprocess.code $listin $params $code]
    }
    default { error "incorrect call to lprocess" }
    }
}

proc _lprocess.func {uplevels listin proc_name {incr_amt {}}} {
    if {[lempty [info proc $proc_name ]]} { error "$proc_name is not a procedure" }
    set params [info args $proc_name]
    if {[lempty $incr_amt] || $incr_amt < 1} { set incr_amt [llength $params] }
    set retval [list]
    for {set i 0} {$i <= [expr {[llength $listin]-[llength $params]}]} {incr i $incr_amt} {
        set values [expr {$i+[llength $params]-1}]
        set retval [concat $retval [uplevel $uplevels "$proc_name [lrange $listin $i $values]"]]
    }
    return $retval
}

proc _lprocess.code {listin params code {incr_amt {}}} {
    proc [set proc_name "lpc_[info level]"] $params $code
    set retval [_lprocess.func 3 $listin $proc_name $incr_amt]
    rename $proc_name {}
    return $retval
}

@describe "lprocess" {
    it "runs code for each member of a list" {
        set times 0
        lprocess [list "1" "2" "3"] {item} {
            upvar times times
            incr times
            return {}
        }
        expect {$times} to be equal to 3
    }
    it "can be used as a filter" {
        set neg5_to_5 [list -5 -4 -3 -2 -1 0 1 2 3 4 5]
        set positives [lprocess $neg5_to_5 {number} {
            if {$number >= 0} { return [list $number] } else { return {} }
        }]
        expect {$positives eq [list 0 1 2 3 4 5]} to be truthy
    }
    it "can be used for transformation" {
        set abc [list "a" "b" "c"]
        set aAbBcC [lprocess $abc {in} { return [list $in [string toupper $in]] }]
        expect {$aAbBcC eq [list "a" "A" "b" "B" "c" "C"]} to be truthy
    }
}

#---------------------------------------------------------------------------------------------------
# Turns {1 2 3} {a b c} {! @ #} into {1 a ! 2 b @ 3 c #}
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc linterleave {args} {
    set numargs [llength $args]
    set max_len 0
    foreach l $args {
        if {[set len [llength $l]] > $max_len} { set max_len $len }
    }
    for {set i 0} {$i < $max_len} {incr i} {
        for {set j 0} {$j < $numargs} {incr j} {
            lappend retval [lindex [lindex $args $j] $i]
        }
    }
    return $retval
}

@describe "linterleave" {
    set abc [list "a" "b" "c"]
    set xyz [list "x" "y" "z"]
    set nums123 [list 1 2 3]
    it "mixes two lists together" {
        expect {[linterleave $abc $xyz] eq [list "a" "x" "b" "y" "c" "z"]} to be truthy
    }
    it "mixes three lists together" {
        expect {[linterleave $abc $xyz $nums123] eq [list "a" "x" 1 "b" "y" 2 "c" "z" 3]} to be truthy
    }
    it "handles lists of different lengths" {
        expect {[linterleave [list "x" "y"] $abc] eq [list "x" "a" "y" "b" "" "c"]} to be truthy
    }
}

#---------------------------------------------------------------------------------------------------
# Turns {{1 2} {3 4} {5 6}} into {{1 3 5} {2 4 6}}
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ltranspose {list2d} {
    set second_dimension [llength [lindex $list2d 0]]
    lassign {} keys retval
    for {set i 0} {$i < $second_dimension} {incr i} {
        set rows($i) {}
        lappend keys $i
    }
    foreach item $list2d {
        if {$second_dimension != [llength $item]} {
            error "lists with variable-length sublists can't be transposed"
        }
        foreach key $keys el $item {
            lappend rows($key) $el
        }
    }
    foreach k $keys {
        lappend retval $rows($k)
    }
    return $retval
}

@describe "ltranspose" {
    it "discards untransposable matrices" {
        expect {[ltranspose [list [list] [list "a" "b"]]]} to throw an error
        expect {[ltranspose [list [list "a" "b"] [list "c"]]]} to throw an error
    }
    it "transposes 2x2 matrix" {
        expect {[ltranspose {{a b} {c d}}] eq {{a c} {b d}}} to be truthy
    }
    it "transposes 1x2 matrix" {
        expect {[ltranspose {{a b}}] eq {a b}} to be truthy
    }
    it "transposes 2x1 matrix" {
        expect {[ltranspose {a b}] eq {{a b}}} to be truthy
    }
    it "transposes 10x10 matrix" {
        set mat [list]
        foreach r {0 1 2 3 4 5 6 7 8 9} {
            set row [list]
            foreach c {0 1 2 3 4 5 6 7 8 9} {
                lappend row [expr {$r * 10 + $c}]
            }
            lappend mat $row
        }
        expect {[ltranspose [ltranspose $mat]] eq $mat} to be truthy
    }
}
