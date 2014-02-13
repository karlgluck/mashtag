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

# Load the cross-version global TCL library file if it doesn't already exist.  This allows this
# file to be sourced relatively by files within this version, or from within the global package.
if {[info proc ::_tcltools::load_library] eq ""} {
    source [file join [file dirname [file normalize [info script]]] .. pkgIndex.tcl]
}

#---------------------------------------------------------------------------------------------------
# Default states for components of TclTools.  This basically forward-declares all @ functions.
#---------------------------------------------------------------------------------------------------

# Turn off self-testing by default. The user can always call `@on describe` to enable this.
@off describe

# Enable debugging only when DEBUG is defined and set to 1
if {[info exists env(DEBUG)] && $env(DEBUG)} {
    @on debug
    @off release
} else {
    @off debug
    @on release
}


#---------------------------------------------------------------------------------------------------
# Invoke the standard library loading routine to load/declare all the files in this package
#---------------------------------------------------------------------------------------------------
::_tcltools::load_library [file dirname [file normalize [info script]]] {
    "debug_release.tcl"
    "assert.tcl"
    "confirm.tcl"
}
