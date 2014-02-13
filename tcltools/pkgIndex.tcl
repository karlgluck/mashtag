####################################################################################################
#
#  TclTools is a library that provides a broad range of general functionality that can be useful in
#  any TCL project. This library supports hosting multiple versions in a central location to ensure
#  releases are consistent.  Compatibility is maintained by enforcing unit-tests.
#
#  Authors:
#    Karl Gluck
#
#---------------------------------------------------------------------------------------------------
namespace eval tcltools {}
namespace eval _tcltools {}


#---------------------------------------------------------------------------------------------------
# Declare each subdirectory to be a package verision.  To obtain that package version, source
# "package.tcl" in that directory.  This allows packages to reference & load themselves without
# having to detect or hard-code their own version number.  This makes the code more flexible!
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::_tcltools::declare_packages {dir} {

    # Each subdirectory (like 1.0, 2.2.5, etc.) is its own version of TclTools.
    foreach subdir [glob -nocomplain -types d [file join $dir "*.*"]] {
        set version [file tail $subdir]
        package ifneeded tcltools $version [format {source "%s"} [file join $subdir "package.tcl"]]
    }

}
::_tcltools::declare_packages [file dirname [file normalize [info script]]]
rename ::_tcltools::declare_packages {}


#---------------------------------------------------------------------------------------------------
# Standard call used by versions' "package.tcl" to load all of the ./src/*.tcl library files
# and initialize subpackage ifneeded's like tcltools.diagnostics
#
# Any file names in the priority_files argument will be loaded from ./src/ in the order listed 
# before any other files are sourced.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc ::_tcltools::load_library {dir priority_files} {

    # Declare a procedure that locates files in this library
    namespace eval :: [format {
        proc tcltools_path {args} { return [eval file join [list {%s}] $args] }
    } $dir]

    # The version is always the last part of the directory
    set version [file tail $dir]

    # Define all files from ./src/<name>/<name>.tcl as the subpackage "tcltools.<name>" so they
    # can be selectively included.  These packages can also refer to one another and not have
    # to worry about dependencies.
    foreach d [glob -nocomplain -types d [file join $dir src "*"]] {
        set name [file tail $d]
        set sublib [file join $d "${name}.tcl"]
        if {[file exists $sublib]} {
            package ifneeded tcltools.${name} $version [format {
                namespace eval :: { source "%s" }
                package provide tcltools.%s %s
            } $sublib $name $version]
        }
    }

    # Load priority files
    array set loaded_priority_files {}
    foreach f $priority_files {
        set f [file join $dir "src" $f]
        if {![file exists $f]} { error "Priority file $f does not exist" }
        namespace eval :: [format { source "%s" } $f]
        set loaded_priority_files($f) 1
    }

    # Load source files from ./src/*.tcl automatically.  They should be arranged such that the
    # order in which they are loaded does not matter.  These are allowed to depend on subpackages
    # of TclTools.
    foreach f [glob -nocomplain -types f [file join $dir "src" "*.tcl"]] {
        if {[info exists loaded_priority_files($f)]} then continue
        namespace eval :: [format { source "%s" } $f]
    }

    package provide tcltools $version
}


#---------------------------------------------------------------------------------------------------
# Toggles one or more @<command> functions.  If a function is turned @on, then it must be defined
# before it is used.  A function can be defined before or after its state is changed, and the
# state can be changed as many times as you like.  However, an @on function must not be called until
# it is defined.
#
# If a function is @off, then it will take any number of arguments and always return 0.
#
# @ procedures that start with @ are not allowed (e.g. @on @foo) because they are reserved for
# storing the arguments and body of the procedure when it is disabled.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc @on {args} {
    foreach procname $args {
        if {[string index $procname 0] eq "@"} {
            error "Illegal @proc name: $procname (did you mean '[string range $procname 1 end]'?)"
        }
        if {"" ne [info proc "@@${procname}"]} {
            lassign [@@${procname}] arglist body
            namespace eval :: [list proc @${procname} $arglist $body]
        } else {
            namespace eval :: [list proc @${procname} {args} [format {
                error "%s was enabled with @on and used before it was defined!"
            } $procname] ]
        }
    }
}
proc @off {args} {
    foreach procname $args {
        if {[string index $procname 0] eq "@"} {
            error "Illegal @proc name: $procname (did you mean '[string range $procname 1 end]'?)"
        }
        namespace eval :: [list proc @${procname} {args} { return 0 }]
    }
}
proc @proc {procname arglist body} {
    if {[string index $procname 0] eq "@"} {
        error "Illegal @proc name: $procname (did you mean '[string range $procname 1 end]'?)"
    }

    # Make sure we haven't defined this procedure yet.  Unlike normal procs, @proc can't be
    # overridden due to the way that @on and @off are handled.
    if {"" ne [info proc @@${procname}]} {
        error "@${procname} already defined!"
    }

    # Declare the procedure that holds the arglist and body
    namespace eval :: [list proc @@${procname} {} [format {return [list {%s} {%s}]} $arglist $body]]

    # Check the proc.  If it already exists (either @on or @off was called) and throws an
    # error, then this proc is definitively enabled with @on.  That means we need to
    # define it so it can be used.
    if {"" ne [info proc @${procname}] && [catch "@procname"]} {
        namespace eval :: [list proc @${procname} $arglist $body]
    }
}

