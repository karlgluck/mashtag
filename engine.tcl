#===============================================================================
# Contains the implementation of the core engine that runs m#tag evaluation.
#
# Notes:
#   - In an effort to be thread-safe, no method modifies or relies on PWD
#
# Authors:
#   Karl Gluck
#===============================================================================

# The main namespace for user-accessible functions
namespace eval ::mash  {} 

# Secondary "utility" namespace for internal definitions, variables, and other
# things that shouldn't be used outside of m# itself.
namespace eval ::_mash {} 

# tcltools is used throughout 
package require tcltools

# The ::mash::core procedure dispatches threads and requires this package.
package require Thread

# Save the root location of this script
set ::_mash::root [file dirname [realpath [info script]]]

#------------------------------------------------------------------------------- 
# Resets all of the contexts, rules and objects used by m#
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::reset {} {
    # calls to ::mash::rule, for incrementing rule IDs
    set ::_mash::rule.calls 0

    unset -nocomplain ::_mash::using_context \
                      ::_mash::input_to_rule_ids \
                      ::_mash::rules

    # The current context stack of 'using' directives.
    set ::_mash::using_context [list {}]

    # Map of mashtag names to the list of rules' ids that reads that mashtag.
    array set ::_mash::input_to_rule_ids {}

    # The rules array is keyed by <id>,<property> pairs, where <id> is the
    # unique ID of a rule, and <property> is a value among "file", "procname",
    # "in", "out", "name", "code" and "conditions".
    # The "*" property contains all the unique rule IDs that have been loaded.
    array set ::_mash::rules {* {}}
}

# Invoke the global reset to initialize variables
::mash::reset

#------------------------------------------------------------------------------- 
# Parses the syntax of the "rule" command in this domain-specific language.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::rule {argv} {
    incr ::_mash::rule.calls
    set id [::_mash::rule.id_being_created $argv]
    set argv [::_mash::rule.pop_name       $argv $id name]
    set argv [::_mash::rule.pop_in         $argv in_vars]
    set argv [::_mash::rule.pop_out        $argv out_vars]
    set argv [::_mash::rule.pop_conditions $argv conditions]
    set argv [::_mash::rule.pop_type_cmd   $argv mash_rule_type_cmd]
    $mash_rule_type_cmd $argv [rule_file] $id $name $in_vars $out_vars $conditions
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule to read the optional rule name from the
# definition. 
#
# Names that can't be used include "in", "out", "if", "when", "always",
# "map", "claim" and "using"
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.pop_name {argv id var} {
    array set not_a_rule_name { in {} out {} if {} when {} always {}
                                map {} claim {} using {} }
    upvar $var name
    if {[info exists not_a_rule_name([lindex $argv 0])] || [llength $argv] == 1} {
        set name "Unnamed Rule ($id)"
    } else {
        set argv [lassign $argv name]
    }
    return $argv
}

#------------------------------------------------------------------------------- 
# Returns the unique ID of the rule that's currently being created
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.id_being_created {rule_argv} {
    set num_rules [array size ::_mash::rules]
    # 1009 = first prime number above 1000
    set v [expr {1009 * (1+${::_mash::rule.calls}) + [string length $rule_argv]}]
    set id [base62 $v]
    while {[info exists ::_mash::rules(${id},code)]} { incr v ; set id [base62 $v] }
    return <${id}>
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.pop_in {argv var} {
    upvar $var in_vars
    set in_vars {}
    if {[lindex $argv 0] eq "in"} {
        set in_vars [lindex $argv 1]
        return [lrange $argv 2 end]
    }
    return $argv 
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.pop_out {argv var} {
    upvar $var out_vars
    set out_vars {}
    if {[lindex $argv 0] eq "out"} {
        set out_vars [lindex $argv 1]
        return [lrange $argv 2 end]
    }
    if {[lindex $argv 0] eq "in"} {
        syntax_error "'in' specified after 'out'; switch the order"
    }
    return $argv 
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.pop_conditions {argv var} {
    upvar $var conditions
    if {![info exists conditions]} { set conditions {} }
    if {[lindex $argv 0] eq "if"} {
        # "if" evaluates the arguments as an expression
        set argv [lassign $argv - condition]
        lappend conditions $condition
        set argv [::_mash::rule.pop_conditions $argv conditions]
        if {[lindex $argv 0] eq "then"} { set argv [lassign $argv -] }
    } elseif {[lindex $argv 0] eq "when"} {
        # "when" evaluates the arguments as a statement
        set argv [lassign $argv - condition]
        lappend conditions [format {[%s]} $condition]
        set argv [::_mash::rule.pop_conditions $argv conditions]
        if {[lindex $argv 0] eq "then"} { set argv [lassign $argv -] }
    } elseif {[lindex $argv 0] eq "always"} {
        set argv [lassign $argv -]
    } else {
        # missing condition is an implied 'always'
    }

    return $argv
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.pop_type_cmd {argv var} {
    upvar $var mash_rule_type_cmd
    array set map {
        claim "::_mash::rule.claim"
        map "::_mash::rule.map" 
    }
    set mash_rule_type_cmd "::_mash::rule.default"
    catch {set mash_rule_type_cmd $map([lindex $argv 0])}
    return $argv
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule to create a claim of invariants.  The rule
# declaration that ends up here looks like:
#
#       rule in {var} always claim {$var > 0}
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.claim {argv file id name in_vars out_vars conditions} {
    lassign $argv _claim_ invariant
    @assert {$_claim eq "claim"}
    if {[llength $argv] != 2} {
        ::mash::syntax_error "'claim' requires 1 argument" $name
    }
    if {[llength $out_vars]} {
        ::mash::syntax_error "'claim' cannot have output variables" $name
    }
    ::mash::using.prepend_args in_vars - conditions

    # The 'continue' in the code makes this claim return itself to the rule
    # stack whenever it is evaluated.
    set code [format {
        if {!(%s)} { error "Claim violated: [rule_name]" }
    } $invariant]

    # Add this rule
    ::mash::add_rule $file $id $name $in_vars {} $conditions $code
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule.  Creates a mapping of input -> output
# variables.  Rule declaration example:
#
#       rule in {a b} out {x y z} when {$a < $b} map {
#           {1 2} {foo bar baz}
#           {3 4} {doc bin lib}
#       }
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.map {argv file id name in_vars out_vars conditions} {
    lassign $argv _map_ mapping
    @assert {$_claim eq "map"}
    if {[llength $argv] != 2} {
        ::mash::syntax_error "'map' requires 1 argument" $name
    }

    # Pull out full-line comments from the mapping
    set mapping [join [lprocess [split $mapping "\n"] {line} {
        # Whitespace then a hash is a comment line.  Can't mix comments into lines.
        if {[regexp {^\s*#.*$} $line]} { return {} } else { return [list $line] }
    }] "\n"]

    # Mix in the current 'using' context
    ::mash::using.prepend_args in_vars out_vars conditions

    # Write the code to perform the mapping
    set array_set_lines {}
    foreach {key value} $mapping {
        if {[llength $key] != [llength $in_vars]} {
            ::mash::syntax_error "Mapping key '$key' doesn't match the number of input variables (expecting values for '${in_vars}')" $name
            continue
        }
        if {[llength $value] != [llength $out_vars]} {
            ::mash::syntax_error "Mapping value '$value' doesn't match the number of output variables (expecting values for '${out_vars}')" $name
            continue
        }
        lappend array_set_lines [format {{%s} {%s}} [eval list $key] [eval list $value]]
    }

    set set_in_vars {}
    foreach var $in_vars {
        lappend set_in_vars [format {[set {%s}]} $var]
    }

    set code [format {
        array set mapping { %s }
        if {[catch { lassign $mapping([list %s]) %s }]} { exception "Key not found in mapping" }
    } [join $array_set_lines "\n"] [join $set_in_vars " "] [join $out_vars " "]] 

    # Create the rule
    ::mash::add_rule $file $id $name $in_vars $out_vars $conditions $code
}

#------------------------------------------------------------------------------- 
# Used internally by ::mash::rule to handle the default rule-creation type.
# Example:
#   rule out {foo} always { set foo 5 }
#   rule out {foo bar} always { return [list 5 10] }
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule.default {argv file id name in_vars out_vars conditions} {
    if {[set num [llength $argv]] != 1} {
        ::mash::syntax_error "default rule must have 1 code block; found $num: $argv" $name
    }
    set code [lindex $argv 0]
    ::mash::using.prepend_args in_vars out_vars conditions
    ::mash::add_rule $file $id $name $in_vars $out_vars $conditions $code
}

#------------------------------------------------------------------------------- 
# Adds a new rule that is evaluated on mashtags.  This does not apply the
# context of the 'using' directive; the caller is responsible for
# handling this.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::add_rule {file id name in out conditions code} {
    @assert {![info exists ::_mash::rules($id)]}

    # Look through the code to make sure there are no conditionally-defined
    # rules.
    set RE {^\s*rule\s}
    foreach line [split $code \n] {
        if {[regexp $RE $line]} {
            ::mash::syntax_error "rules cannot conditionally define other rules; see 'using'"
        }
    }

    # Deduplicate the conditions, but preserve order
    set conditions [lunique $conditions]

    # Turn the code into a procedure
    set procname [::_mash::add_rule.code_to_proc $file $id $name $in $out $conditions $code]

    # Set the rule definition into keys of the rules array
    foreach var {name in out conditions code file procname} {
        set ::_mash::rules($id,$var) [set $var]
    }

    # Reference this rule for each of the input variables
    foreach var $in { lappend ::_mash::input_to_rule_ids($var) $id }

    # Make sure at least an empty list is present for each of the output
    # variables.  This makes processing easier.
    foreach var $out {
        if {![info exists ::_mash::input_to_rule_ids($var)]} {
            set ::_mash::input_to_rule_ids($var) [list]
        }
    }

    # Add to the list of all rules
    lappend ::_mash::rules(*) $id
}


#------------------------------------------------------------------------------- 
# Creates a TCL procedure for the given rule.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::add_rule.code_to_proc {file id name in out conditions code} {

    # Always use the full path to the rule
    set file [realpath $file]

    # Write the code read input variables from the "context" array in the caller
    set in_code {}
    foreach var $in {
        if {[string range $var end-1 end] eq ".*"} {
            # glob-matches input variables
            lappend in_code [format {
                foreach {var value} [array get {__%s_context} {%s}] {
                    set $var $value
                }
            } $id $var]
        } else {
            # Not a glob-match. Just read the single variable.
            lappend in_code [format {set {%s} ${__%s_context(%s)}} $var $id $var]
        }
    }
    set in_code [join $in_code \n]

    # build the conditions
    set conditions_code {}
    foreach condition $conditions {
        lappend conditions_code [format {
            if {!(%s)} { return [list {NOT evaluated.  Condition %s requires: %s} {} {}] }
        } $condition [llength $conditions_code] $condition]
    }
    set conditions_code [join $conditions_code \n]

    set procname "::_mash::rules.rule_${id}"
    proc $procname {} [format {
        proc ::rule_file {} { return {%s} }
        proc ::rule_name {} { return {%s} }

        # read input variables from context
        upvar context {__%s_context}
        proc ::has {varname} { upvar_closest {__%s_context} context ; return [expr {[info exists context($varname)] || [lnotempty [array get context $varname]]}] }
        %s

        # check conditions
        %s

        # evaluate body
        switch -- [set ::_mash::__catch_code [catch {%s} ::_mash::__catch_msg]] {
            0 -
            2 -
            3 {
                # Code ended (0), or there was a "return" (2), or a "break" (3)
                # If 3, should have been caused by calling 'exception'.
                if {$::_mash::__catch_code == 3} {
                    set problems {}
                    set out {}
                } else {
                    set problems [::_mash::add_rule.code_to_proc.local_vars_array {%s} out]
                    if {[lnotempty $problems] && (${::_mash::__catch_code} != 4)} {
                        # If a variable wasn't set and the user didn't say "continue", ignore
                        # all outputs.
                        set out {}
                    }
                }
                set msg [expr {$::_mash::__catch_code == 0 ? "" : ${::_mash::__catch_msg}}]
                return [list $msg $problems $out]
            }
            1 {
                # There was an error in the code.  Pass the error through.
                error ${::_mash::__catch_msg}
            }
            4 {
                error "'continue' in top level of rule"
            }
        }

    } $file $name $id $id $in_code $conditions_code $code $out]

    # Return the created procedure
    return $procname
}

#------------------------------------------------------------------------------- 
# Called from within a defined rule to take locally-defined variables matching
# the specified patterns and create a key-value pair mapping in 'out_var'
# in the caller context with each of their values.
#
# This code is constructed such that even if $out_var is in $patterns,
# it will not be overwritten until its existing value has been read.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::add_rule.code_to_proc.local_vars_array {patterns out_var} {
    set local_out {}
    set retval {}
    foreach pattern $patterns {
        set vars [uplevel 1 [format {info vars {%s}} $pattern]]
        if {[llength $vars]} {
            foreach v $vars { lappend local_out $v [string trim [uplevel 1 "set {$v}"]] }
        } else {
            lappend retval "Didn't set output {$pattern}"
        }
    }
    upvar $out_var out
    set out $local_out
    return $retval
}


#------------------------------------------------------------------------------- 
# Obtains the current 'using' context for new rules into the variables named
# as arguments.  Prepends the arguments to the named input variables.  If an
# input variable is named "-" it will not be set.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::using.prepend_args {in_var out_var conditions_var} {
    lassign [lvartop ::_mash::using_context] context_in context_out context_conditions
    if {$in_var ne "-"} {
        upvar $in_var in
        set in [concat $context_in $in]
    }
    if {$out_var ne "-"} {
        upvar $out_var out
        set out [concat $context_out $out]
    }
    if {$conditions_var ne "-"} {
        upvar $conditions_var conditions
        set conditions [concat $context_conditions $conditions]
    }
}


#------------------------------------------------------------------------------- 
# Defines rules within a new 'using' directive.  The 'using' block groups
# a common set of rules with some set of inputs/outputs/conditions so that
# code doesn't need to be repeated, and rules can be nonconditionally defined.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::using {argv} {
    lassign $argv parameters _define_ rules
    if {[llength $argv] != 3 || $_define_ ne "define"} {
        ::mash::syntax_error "'using' incorrect; expecting: using {parameters} define {rules}"
    }

    # Get extra parameters to use for rules
    set parameters [::_mash::rule.pop_in         $parameters using_in_vars]
    set parameters [::_mash::rule.pop_out        $parameters using_out_vars]
    set parameters [::_mash::rule.pop_conditions $parameters using_conditions]

    # Add these so that ::mash::add_rule automatically
    # includes these additional values
    ::_mash::using.push_args $using_in_vars $using_out_vars $using_conditions

    # Evaluate the rules from this context
    set code [catch {uplevel #0 $rules} msg]

    # Pop off the rule context
    ::_mash::using.pop_args

    # Return the error, if any
    if {$code} { error $msg }
}


#------------------------------------------------------------------------------- 
# Pushes a new context on to the stack.  The top of the stack (front of the
# ::_mash::using_context list) is always the complete context.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::using.push_args {in out conditions} {
    # push to the front
    ::mash::using.prepend_args in out conditions
    #set ::_mash::using_context [concat [list [list $in $out $conditions]] \
    #                                   $::_mash::using_context]
    lvarpush ::_mash::using_context [list $in $out $conditions]
}

#------------------------------------------------------------------------------- 
# Pops the last added context off of the stack.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::using.pop_args {} {
    confirm {[llength $::_mash::using_context] > 1} else { return }
    #set ::_mash::using_context [lassign ::_mash::using_context -]
    lvarpop ::_mash::using_context
}

#------------------------------------------------------------------------------- 
# Displays a syntax error to the user.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::syntax_error {msg {rule_name ""}} {
    if {$rule_name ne ""} {
        error "Syntax Error\nFile:  [rule_file]\nRule:  $rule_name\n\n\t$msg"
    } else {
        error "Syntax Error\nFile:  [rule_file]\n\n\t$msg"
    }
}

#------------------------------------------------------------------------------- 
# Reads a set of rules from a file.  This command is made as robust as possible
# so it hijacks the calls to m# commands and batches them at the end.
#
# Writes:
#   ::_mash::using_context
#   ::_mash::input_to_rule_ids
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::load_rules {code {path {}}} {

    # Hijack functions so we can push everything on a stack and evaluate them
    # one at a time.  This way, we can get stuff evaluated in parallel.
    set ::_mash::load_rules.hijacked_calls [list]
    set hijacked_procs [list rule using metric]
    foreach fn $hijacked_procs {
        rename ::$fn ::_mash::load_rules.hijacked.$fn
        proc ::$fn {args} { lappend {::_mash::load_rules.hijacked_calls} [info level 0] }
    }

    # Load the file
    if {$path ne {}} {
        proc ::rule_file {} [format {return {%s}} $path]
    } else {
        proc ::rule_file {} { error "Dynamic rules (those not loaded from a rules file) cannot use \[rule_file\] or \[rule_relative_path\]" }
    }
    set had_error [catch {uplevel #0 $code} msg]

    # If there was an error, go through and evaluate the file line-by-line to find
    # where it occurred.
    if {$had_error} {
        set error_text $msg
        set error_line 0
        set error_line_range 0
        set code_lines [split $code \n]
        set statement {}
        while {[llength $code_lines]} {
            set code_lines [lassign $code_lines line]
            append statement "$line\n"
            if {[info complete $statement]} {
                if {[catch { uplevel #0 $statement } $msg]} {
                    set error_text $msg
                    break 
                }
                set statement {}
                set error_line_range 0
            }
            incr error_line
            incr error_line_range
        }
        if {![regexp {\s*} $statement ]} {
            set error_text "Incomplete statement at end of file"
        }
    }

    # Restore the hijacked procs
    foreach fn $hijacked_procs {
        rename ::$fn {}
        rename ::_mash::load_rules.hijacked.$fn ::$fn
    }

    # Check for problems (important to do this AFTER restoring the hijacked methods) 
    if {$had_error} { error "Syntax error around lines [expr {$error_line - $error_line_range}] - $error_line in [file tail $path]:\n\n$error_text\n\n" }

    # Run through the set of hijacked calls and invoke each, one at a time,
    # so that the 
    set errors [list]
    foreach call ${::_mash::load_rules.hijacked_calls} {
        set fn [lindex $call 0]
        set key "count(${fn})"
        if {[info exists $key]} { incr $key } else { set $key 0 }
        if {[catch {uplevel #0 $call} msg]} {
            set snippet "[string range $call 0 256]..."
            lappend errors "Error during $fn #[set $key]\n\t${snippet}:\n$msg"
        }
    }

    # Map the rule file back
    proc ::rule_file {} { error "[info level 0] - not overridden" }

    # Check for errors
    if {[llength $errors]} {
        set s [expr {[llength $errors] != 1 ? "s" : ""}]
        error "[llength $errors] Error$s in [file tail $path]\nPath: $path\n\n\n[join $errors \n\n----\n\n]"
    }
}

#------------------------------------------------------------------------------- 
# Writes all of the m# properties provided as input to the disk.  To optimize
# for speed, the data should only contain those values that have been changed.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::write_properties {object_path properties} {
    foreach {k v} $properties {
        set components [split $k .]
        set tag [lindex $components end]
        set subpath [lrange $components 0 end-1] 
        set tag_path [eval file join [list $object_path] $subpath ]
        if {![file isdirectory $tag_path]} {
            if {[catch {file mkdir $tag_path} msg]} {
                puts stderr "Couldn't make path for mashtag:  $tag_path\n$msg"
                continue
            }
        }
        set tag_path [file join $tag_path "#${tag}"]
        if {[regexp {^\s*$} $v]} {
            if {[file exists $tag_path]} { file delete $tag_path }
        } else {
            fwrite $tag_path $v
            catch { file attributes $tag_path -permissions ug+rw } ; # make sure it's user/group writable
        }
    }
}

#------------------------------------------------------------------------------- 
# Returns the string "$value", or "<truncated $value>..." if the string is long.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::truncated_string {value} {
    if {[string length $value] > 32} {
        return [format {%s...} [string range $value 0 29]]
    } else {
        return $value
    }
}

#------------------------------------------------------------------------------- 
# Returns a string that names the given rule in a human-readable way
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::rule_reference {rule_id} {
    return "${rule_id}.\"$::_mash::rules($rule_id,name)\""
}

#------------------------------------------------------------------------------- 
# Applys all of the current m# rules to the given object.  This procedure
# returns a list of a 5 items:
#   properties (array) - maps names to values for m#tags, the same way as the
#                        input, but only listing tags whose value changed
#   errors - A list of {trace_index rule_reference property_name message}
#            for each error that occurred.
#   trace (array) - maps trace indices [0,1,...,n] to a text record of what happend
#           at that step in the evaluation
#   rule (array) - maps rule IDs to a text record of all the actions that the rule
#          took during execution
#   property log (array) - for each property, mentions what happened
#   profiling(array) - maps "total" and each rule ID to the milliseconds of
#           execution time taken during evaluation.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::mash_object {object_path properties} {

    proc ::object_relative_path {args} \
        [format { return [file normalize [eval file join {%s} $args]] } $object_path]

    # The "context" variable is used as input by each rule's proc 
    array set context $properties

    # tracks which properties have been written by these rules to look for
    # conflicts in the rules themselves
    array set trace_log {}
    array set rule_log {}
    array set property_log {}
    array set property_write_log {}
    set errors {}

    # Initialize the profiling array
    array set profiling {}
    foreach rule_id $::_mash::rules(*) {
        set profiling($rule_id) 0
    }
    set profiling(total) [clock clicks -millisec]

    # Iterate through rules until they are all resolved.  Guaranteed to
    # terminate if there are no cycles.
    set worklist $::_mash::rules(*)
    while {[llength $worklist]} {

        # pop the next rule
        set trace_index [array size trace_log]
        set worklist [lassign $worklist rule_id]
        set name $::_mash::rules($rule_id,name)
        set rule_reference [::_mash::rule_reference $rule_id]
        set profiling_t0 [clock clicks -millisec]

        # determine whether all the inputs are available
        set all_inputs [list]
        set missing_inputs [list]
        foreach in $::_mash::rules($rule_id,in) {
            set inputs [array names context $in]
            if {[lempty $inputs]} {
                lappend missing_inputs "{{$in}}"
            } else {
                set all_inputs [concat $all_inputs $inputs]
            }
        }
        if {[lnotempty $missing_inputs]} {
            set missing_inputs [join $missing_inputs ", "]
            lappend trace_log($trace_index) \
                "{{$rule_reference}} not evaluated because inputs are missing: $missing_inputs"
            lappend rule_log($rule_id) \
                "{{$trace_index}} : Rule not evaluated because inputs are missing: $missing_inputs"
            continue
        }

        set argument_values [list]
        foreach property $all_inputs {
            set truncated_value [::_mash::truncated_string $context($property)]
            lappend argument_values "{{$property}} = $truncated_value"
            lappend property_log($property) "{{$trace_index}} : Read by {{$rule_reference}} (= $truncated_value)"
        }
        if {[lempty $argument_values]} {
            set output ": Called with no arguments."
        } else {
            set output ": Called with:  [join $argument_values {, }]"
        }
        lappend rule_log($rule_id) "{{$trace_index}} $output"
        lappend trace_log($trace_index) "{{$rule_reference}} $output"

        # evaluate the rule on the current context
        if {[catch {set retval [$::_mash::rules($rule_id,procname)]} msg]} {
            lappend errors [list $trace_index $rule_reference {} $msg]
            set output ": ERROR - $msg"
            lappend trace_log($trace_index) "{{$rule_reference}} $output"
            lappend rule_log($rule_id) "{{$trace_index}} $output"
            continue ; # start on the next entry in the worklist
        }


        # Check each written property to see if it
        # changed.  If it changed and was already
        # written by a rule, there is a rule conflict
        # that needs to be resolved.
        lassign $retval msg problems out
        if {[string length $msg]} {
            set output ": $msg"
            lappend trace_log($trace_index) "{{$rule_reference}} $output"
            lappend rule_log($rule_id) "{{$trace_index}} $output"
        } elseif {[lempty $out]} {
            lappend trace_log($trace_index) "{{$rule_reference}} : Evaluated (no output)"
            lappend rule_log($rule_id) "{{$trace_index}} : Evaluated (no output)"
        }
        foreach {property value} $out {

            # record the write
            lappend property_write_log($property) [list $rule_id $trace_index]

            # create a loggable version of the value
            set truncated_value [::_mash::truncated_string $value]

            # if the write had no effect, no more processing is needed
            if {[info exists context($property)] && $context($property) eq $value} {
                lappend property_log($property) "{{$trace_index}} : Written but unchanged by {{$rule_reference}} (value = $truncated_value)"
                set output ": Wrote but didn't change {{$property}} (value = $truncated_value)"
                lappend trace_log($trace_index) "{{$rule_reference}} $output"
                lappend rule_log($rule_id) "{{$trace_index}} $output"
                continue
            }

            # See if there was a conflict with the write from a different rule.  Ignore
            # conflicting writes from this same rule, since that just means that the inputs
            # to this rule changed and it's being re-evaluated.
            lassign [lindex $property_write_log($property) end-1] previous_writer_rule_id previous_writer_trace_index
            if {[llength $property_write_log($property)] > 1 && ($previous_writer_rule_id != $rule_id)} {
                set previous_writer_reference [::_mash::rule_reference $previous_writer_rule_id]
                set output ": ERROR - Wrote a conflicting value to {{$property}}, which was already written by {{$previous_writer_reference}} at trace index {{$previous_writer_trace_index}}"
                lappend errors [list $trace_index $rule_reference $property $output]
                lappend trace_log($trace_index) "{{$rule_reference}} $output"
                lappend rule_log($rule_id) "{{$trace_index}} $output"
                lappend property_log($property) \
                    "{{$trace_index}} : ERROR - Conflicting value written by {{$rule_reference}}"
                lappend property_log($property) \
                    "\t\tLast writer: {{$previous_writer_reference}}"
                lappend property_log($property) \
                    "\t\tPrevious value: [::_mash::truncated_string $context($property)]"
                lappend property_log($property) \
                    "\t\tNew value: $truncated_value"
            } else {
                lappend property_log($property) "{{$trace_index}} : New value written by {{$rule_reference}} (= $truncated_value)"
            }

            # change the value
            set context($property) $value
            set output ": Wrote new value to {{$property}} (= $truncated_value)"
            lappend trace_log($trace_index) "{{$rule_reference}} $output"
            lappend rule_log($rule_id) "{{$trace_index}} $output"

            # since this property changed, rules taking it as
            # input need to be re-evaluated
            if {[info exists ::_mash::input_to_rule_ids($property)]} {
                foreach activated_rule $::_mash::input_to_rule_ids($property) {
                    set activated_rule_ref [::_mash::rule_reference $activated_rule]
                    lappend property_log($property) "{{$trace_index}} : Triggered evaluation of {{$activated_rule_ref}}"
                    lappend trace_log($trace_index) "{{$rule_reference}} : Triggered evaluation of {{$activated_rule_ref}}"
                    lappend rule_log($activated_rule) "{{$trace_index}} : Added to worklist by {{$rule_reference}} because {{$property}} changed (= $truncated_value)"
                }
                set worklist [concat $worklist \
                                     $::_mash::input_to_rule_ids($property)]
            }

        }

        # ensure the worklist isn't redundant
        set worklist [lunique $worklist]

        if {[lnotempty $problems]} {
            set output ": ERROR - \n[join $problems \"\n\t\"]"
            lappend errors [list $trace_index $rule_reference {} $output]
            lappend trace_log($trace_index) "{{$rule_reference}} $output"
            lappend rule_log($rule_id) "{{$trace_index}} $output"
        }

        set millisec [expr {[clock clicks -millisec] - $profiling_t0}]
        incr profiling($rule_id) $millisec
    }

    # Prune the context to just those tags that changed
    foreach {tag value} $properties {
        if {$context($tag) eq $value} { unset context($tag) }
    }

    # End profiling
    set profiling(total) [expr {[clock clicks -millisec] - $profiling(total)}]

    # Return the results of the mash
    return [list [array get context] $errors [array get trace_log] [array get rule_log] [array get property_log] [array get profiling]]
}

#------------------------------------------------------------------------------- 
# Takes the full return value of a call to ::mash::mash_object and textualizes
# the results so that they can be printed to a log file.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::mash_object.results_to_txt {retval {existing_properties {}}} {
    lassign $retval properties errors trace_log rule_log property_log profiling_arr

    # Put the logs in order
    set property_log [lprocess $property_log {k v} { return [list [list $k $v]] }]
    set property_log [lsort -index 0 -dictionary $property_log]
    set rule_log [lprocess $rule_log {k v} { return [list [list $k $v]] }]
    set rule_log [lsort -index 0 -dictionary $rule_log]
    

    set summary [list]
    set txt [list]

    set bar [string repeat "=" 80]

    # Summary start
    lappend summary "${bar}\n                                     SUMMARY\n${bar}\n\n"

    # Error section
    set len [llength $errors]
    set s [expr {$len != 1 ? "s were" : " was"}]
    lappend summary "Errors:         $len"
    if {[lnotempty $errors]} {
        lappend txt "${bar}\n    $len error$s encountered!\n${bar}\n\n"
        foreach error $errors {
            lassign $error trace_index rule_ref property
            lappend txt "    * Trace Index:  {{$trace_index}}"
            lappend txt "      Rule:         {{$rule_ref}}"
            if {[string length $property]} {
                lappend txt "      Property:     {{$property}}"
            }
        }
    }

    lappend txt {} {}

    # Written tags section
    lappend txt "${bar}\n    Updated m#tags\n${bar}\n\n"
    set new_tags 0
    set txt_to_append [list]
    set new_tags [expr {[llength $properties] / 2}]
    foreach {k v} $properties {
        set value [string range $v 0 66]
        if {[info exists existing_properties_a($k)]} {
            set reason "Was: [string range $existing_properties_a($k) 0 66]"
        } else {
            set reason "(new tag)"
        }
        set value [regsub -all -- "\n" $value "\\n"]
        set reason [regsub -all -- "\n" $reason "\\n"]
        lappend txt_to_append "    * $k\n           = $value\n        $reason"
    }
    set txt_to_append [lsort -dictionary $txt_to_append]
    set txt [concat $txt $txt_to_append]
    lappend summary "Updated m#tags: $new_tags"

    lappend txt {} {}

    # Execution Trace
    array set trace $trace_log
    set len [array size trace]
    lappend txt "${bar}\n    Execution Trace ($len Steps) \n${bar}\n\n"
    lappend summary "Steps:          $len"
    for {set i 0} {$i < $len} {incr i} {
        lappend txt "  $i\n[string repeat - 32]\n[join $trace($i) \n]\n"
    }

    lappend txt {} {}

    # Rule Evaluations
    lappend txt "${bar}\n    Rule Evaluations\n${bar}\n\n"
    lappend summary "Rules:          [llength $rule_log]"
    foreach kv $rule_log {
        lassign $kv k v
        lappend txt [set title [::_mash::rule_reference $k]]
        lappend txt [string repeat - [string length $title]]
        lappend txt "[join $v \n]\n"
    }

    lappend txt {} {}

    # Properties
    lappend txt "${bar}\n    Properties\n${bar}\n\n"
    lappend summary "Properties:     [llength $property_log]"
    array set output_to_rule_ids {}
    foreach rule_id $::_mash::rules(*) {
        foreach output $::_mash::rules($rule_id,out) {
            lappend output_to_rule_ids($output) $rule_id
        }
    }
    foreach kv $property_log {
        lassign $kv k v
        lappend txt $k
        lappend txt [string repeat - [lmax [list 16 [string length $k]]]]

        set read_k $k
        set has_writers [info exists output_to_rule_ids($read_k)]
        if {!$has_writers} {
            # Check for (single-level) glob-match
            set read_k [string range $read_k 0 [string last . $read_k]]*
            set has_writers [info exists output_to_rule_ids($read_k)]
        }
        if {$has_writers} {
            lappend txt {} "Rules that write this property:"
            foreach rule_id $output_to_rule_ids($read_k) {
                lappend txt "    * {{[::_mash::rule_reference $rule_id]}}"
            }
        } else {
            lappend txt {} "No rules write this property (or it is written by .* match)"
        }
        if {[info exists ::_mash::input_to_rule_ids($k)]} {
            lappend txt {} "Rules that read this property:"
            foreach rule_id $::_mash::input_to_rule_ids($k) {
                lappend txt "    * {{[::_mash::rule_reference $rule_id]}}"
            }
        } else {
            lappend txt {} "No rules read this property."
        }
        lappend txt {} "Execution Log:" {} "[join $v \n]\n" {} {}
    }

    # Execution time
    set profiling_sort [list]
    foreach {k v} $profiling_arr {
        lappend profiling_sort [list $k $v]
    }
    set profiling_sort [lsort -index 1 -integer -decreasing $profiling_sort]
    lappend txt "${bar}\n   Profiling\n${bar}\n\n"
    lassign [lindex $profiling_sort 0] - profiling_total
    foreach kv $profiling_sort {
        lassign $kv k v
        if {$k ne "total"} { set k [::_mash::rule_reference $k] }
        set percent [format {%0.2f%%} [expr {(100.0*$v)/$profiling_total}]]
        lappend txt [format {%16d %-8s %s} $v $percent $k]
    }
    lappend txt {}

    # Rules
    lappend txt "${bar}\n    Rule Definitions\n${bar}\n\n"
    foreach rule $::_mash::rules(*) {
        lappend txt [set title [::_mash::rule_reference $rule]]
        lappend txt [string repeat - [string length $title]]
        lappend txt "File:  $::_mash::rules($rule,file)"
        lappend txt "In:    $::_mash::rules($rule,in)"
        lappend txt "Out:   $::_mash::rules($rule,out)"
        lappend txt "If:    $::_mash::rules($rule,conditions)"
        lappend txt "Exec:  "
        lappend txt "Code:  {\n$::_mash::rules($rule,code)\n}"
        lappend txt {}
    }

    # Compile the string
    return [join [concat $summary [list {} {}] $txt] "\n"]
}

#------------------------------------------------------------------------------- 
# Runs the m#tag processing algorithm on the set of input objects using the
# given list of rules.  This method uses parallel processing to speed up
# evaluation.  It opens up to $concurrent_io_channels files at the same time
# and processes objects in up to $worker_threads separate threads.  The objects
# are handled in batches of $batch_size to limit memory usage and keep the
# TCL interpreter happy. 
#
# "rules" is a list of paths to rules files and/or code to evaluate.  Any rules
# currently loaded into m# will be replaced with this set of rules.  Passing
# no rules is valid and just causes objects' tags to be loaded into memory
# using concurrent I/O.
#
# The function $callback is called periodically throughout the function
# with updates to what the function is doing.
#
# 'callback' method signature:
#
#   proc callback {objects_count objects_scanned objects_processed tags_count tags_loaded}
#
# Return value is a list of:
#   object              path
#   properties          list of {m#tag value ...}
#   modified properties
#   error log
#   trace log
#   rules log
#   property log
#
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::mash::core {objects concurrent_io_channels worker_threads batch_size rules {callback {}}} {

    # Load up the rules from the input
    ::mash::reset
    foreach rule $rules {
        if {[file exists $rule]} {
            set rule [realpath $rule] 
            ::mash::load_rules [fread $rule] $rule
        } elseif {[info complete $rule]} {
            ::mash::load_rules $code 
        } else {
            # try to figure out what is wrong with the declaration
            set fuzzy 0
            incr fuzzy [expr {[llength [file split $rule]] > 1}]
            incr fuzzy [expr {-1 == [string first \{ $rule}]
            incr fuzzy [expr {-1 == [string first \} $rule}]
            incr fuzzy [expr {[string match "/*" $rule}]

            if {(-1 == [string first "\n" $rule]) && $fuzzy >= 2} {
                error "Rule file doesn't exist:  $rule"
            } else {
                error "Rule declaration is incomplete, or specifies a file that doesn't exist:  $rule"
            }
        }
    }

    # Set up shared variables
    array set ::_mash::core_objects { * {} }
    array set ::_mash::core_vars {
        pending {}
        objects_count 0
        objects_scanned 0
        objects_processed 0
        open_channels 0
        tags_count 0
        tags_loaded 0
    }
    set ::_mash::core_vars(objects_count) [llength $objects]

    # Save the current state of this application into a script that
    # will be passed to the worker threads.  Add thread-specific 
    # new functions to the code, as well.  This will be used later,
    # but should be recorded now.
    set thread_code [interpreter_state]
    append thread_code {
        proc ::async_mash_object {object properties} {
            return [concat [list $object] \
                           [list $properties] \
                           [::mash::mash_object $object $properties]]
        }

        # Don't allow the pwd to be changed, since this affects all threads
        proc cd {args} { error "(m#) Changing the CWD is disabled in threaded m#" }

        thread::wait
    }

    # Limit number of worker threads to number of objects
    set worker_threads [lmin [list $worker_threads $::_mash::core_vars(objects_count)]]

    # Create threads for processing objects in parallel
    for {set i 0} {$i < $worker_threads} {incr i} {
        set threads($i) [thread::create -joinable $thread_code]
    }
    unset thread_code

    # Set up a function to automatically invoke the callback
    if {$callback ne {}} {
        proc ::_mash::core.do_callback {} [format {
            %s $::_mash::core_vars(objects_count) \
               $::_mash::core_vars(objects_scanned) \
               $::_mash::core_vars(objects_processed) \
               $::_mash::core_vars(tags_count) \
               $::_mash::core_vars(tags_loaded)
        } $callback]
    } else {
        proc ::_mash::core.do_callback {} {}
    }

    set ::_mash::core_vars(results,filename) [file join /tmp "mash_engine_results_[unique_key]"]
    set ::_mash::core_vars(results,fp) [open ${::_mash::core_vars(results,filename)} "w+"]

    # Evaluate objects in batches
    set batch_size [lmax [list $batch_size $worker_threads]]
    while {[llength $objects]} {
        set batch_objects [lrange $objects 0 [expr {$batch_size-1}]]
        set objects [lrange $objects $batch_size end]
        ::_mash::core $batch_objects $concurrent_io_channels [lempty $rules]
    }

    # Release all of the threads
    foreach {- thread_id} [array get threads] {

        # Kick the thread out thread::wait
        thread::release $thread_id

        # Wait for the thread to terminate
        thread::join $thread_id
    }


    # Return the results of evaluating all the rules
    close ${::_mash::core_vars(results,fp)}
    set path ${::_mash::core_vars(results,filename)}
    unset ::_mash::core_vars

    # Return the results of evaluating all the rules
    return [list $path]
}

proc ::mash::core.foreach_result_in_file {result_remaining_vars path code} {
    if {[llength $result_remaining_vars] == 2} {
        lassign $result_remaining_vars result_var remaining_var
        upvar $result_var result
        upvar $remaining_var remaining
    } else {
        upvar $result_remaining_vars result
    }
    set result {}
    set lines 0
    set fp [open $path "r"]
    seek $fp 0 end
    set total [tell $fp]
    seek $fp 0 start
    while {[gets $fp line] >= 0} {
        append result "${line}\n"
        set remaining [expr {$total - [tell $fp]}]
        incr lines
        if {[info complete $result]} {
            if {[set err [catch {uplevel 1 $code} msg]]} {
                switch $err {
                0 -
                4 {}
                1 -
                2 { return -code $err $msg }
                3 { return {} }
                }
            }
            set result {}
            set lines 0
        }
    }
    close $fp
    @assert {$lines == 0}
}

# MUST be called ONLY from within ::mash::core
proc ::_mash::core {objects concurrent_io_channels no_rules} {
    upvar "threads" threads

    # Reset the objects being processed for this batch
    array set ::_mash::core_objects { * {} }
    array set ::_mash::core_vars {
        pending {}
        open_channels 0
    }

    # Find all of the tags in the object paths and dispatch reads for them
    foreach object $objects {

        # Ensure this object exists
        if {![file isdirectory $object]} {
            error "Object directory does not exist: $object"
        }

        # Add to the list of all objects
        lappend ::_mash::core_objects(*) $object
        set ::_mash::core_objects($object,*) {}

        # Search for all m#tags and add them as properties
        set worklist [list $object {}]
        while {[llength $worklist]} {
            set worklist [lassign $worklist path base]

            set links       [glob -nocomplain -type l -- [file join $path "*"]] 
            set files       [lsubtract [glob -nocomplain -type f -- [file join $path "#*"]] $links]
            set directories [lsubtract [glob -nocomplain -type d -- [file join $path "*"]] $links]
            foreach f $files {
                lappend ::_mash::core_vars(pending) $object [format {%s%s} $base [string range [file tail $f] 1 end]] [file normalize $f]
            }
            foreach d $directories {
                lappend worklist $d [format {%s%s.} $base [file tail $d]]
            }

            # Add to the tag stats
            incr ::_mash::core_vars(tags_count) [llength $files]

            # Dispatch property reads for the newly found properties
            update
            ::_mash::core.dispatch_property_reads [expr {$concurrent_io_channels / 4}]

            # Invoke the callback
            ::_mash::core.do_callback
        }

        # Invoke the callback
        incr ::_mash::core_vars(objects_scanned)

        ::_mash::core.do_callback
    }

    # Wait for read completions for all of the object tags
    while {[::_mash::core.dispatch_property_reads $concurrent_io_channels]} {
        after 1000 { set ::_mash::core.dispatch_property_reads_vwait {} }
        vwait ::_mash::core.dispatch_property_reads_vwait 
        ::_mash::core.do_callback
    }

    # Sync to callback
    ::_mash::core.do_callback

    # If there are no rules to evaluate, we can exit early 
    if {$no_rules} {
        foreach object $::_mash::core_objects(*) {
            set properties [list]
            foreach tag $::_mash::core_objects($object,*) {
                lappend properties $tag $::_mash::core_objects($object,$tag)
            }
            set result [list $object $properties {} {} {} {} {}]
            puts ${::_mash::core_vars(results,fp)} $result
        }
        set ::_mash::core_vars(objects_processed) $::_mash::core_vars(objects_count)
        ::_mash::core.do_callback
        return {}
    }

    # Dispatch processing into the worker thread pool
    set thread_index 0
    foreach object $::_mash::core_objects(*) {

        # Convert properties to a mashable format
        set properties [list]
        foreach tag $::_mash::core_objects($object,*) {
            lappend properties $tag $::_mash::core_objects($object,$tag)
        }

        # Dispatch to a worker thread
        thread::send -async $threads($thread_index) [list ::async_mash_object $object $properties] ::result

        # Move to the next worker thread
        set thread_index [expr {($thread_index + 1) % [array size threads]}]
    }

    # Wait for all results to come in
    foreach object $::_mash::core_objects(*) {
        vwait ::result
        puts ${::_mash::core_vars(results,fp)} $::result
        incr ::_mash::core_vars(objects_processed)
        ::_mash::core.do_callback
    }

    # Clean up core objects
    unset ::_mash::core_objects

    # Return nothing (results are printed to the results file)
    return {}
}

#------------------------------------------------------------------------------- 
# Reads properties from the current pending set, dispatching up to
# channels_limit number of total concurrent reads as long as there are less than
# channels_threshold concurrent reads outstanding.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::core.dispatch_property_reads {channels_limit} {

    set channels_threshold [expr {$channels_limit * 5 / 6}]
    if {$::_mash::core_vars(open_channels) >= $channels_threshold} { return 1 }

    # Dispatch next set of reads
    while {[llength $::_mash::core_vars(pending)] && $::_mash::core_vars(open_channels) < $channels_limit} {
        set ::_mash::core_vars(pending) [lassign $::_mash::core_vars(pending) object property path]

        # Add this property to the object's list
        lappend ::_mash::core_objects($object,*) $property
        set ::_mash::core_objects($object,$property) {}

        # Start an asynchronous read of the property tag
        set channel [open $path "r"]
        incr ::_mash::core_vars(open_channels)
        fconfigure $channel -blocking 0
        fileevent $channel readable [list ::_mash::core.dispatch_property_reads.gotdata $channel $object $property $path $channels_threshold]
    }

    # Return 1 if processing is still needed
    return [expr {[lnotempty $::_mash::core_vars(pending)] || $::_mash::core_vars(open_channels) > 0}]
}

#------------------------------------------------------------------------------- 
# Invoked when the asynchronous I/O channel has new data for a tag
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc ::_mash::core.dispatch_property_reads.gotdata {channel object property path channels_threshold} {
    if {[eof $channel]} {

        # The channel has no more data, so close it and trigger another read
        incr ::_mash::core_vars(tags_loaded)
        close $channel
        incr ::_mash::core_vars(open_channels) -1
        if {($::_mash::core_vars(open_channels) < $channels_threshold && [llength $::_mash::core_vars(pending)])
            || ($::_mash::core_vars(open_channels) == 0)} {
            set ::_mash::core.dispatch_property_reads_vwait {}
        }
    } else {
        append ::_mash::core_objects($object,$property) [read -nonewline $channel]
    }
}
