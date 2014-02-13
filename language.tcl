# global constants
package require tcltools

namespace eval ::mash  {} 
namespace eval ::_mash {} 


#---------------------------------------------------------------------------------------------------
# Rules derive properties of an object from other properties and/or files on disk.
#
# The syntax for a rule is:
#   rule ["optional name of rule"] \
#       in  { optional variables to read } \
#       out  { variables to write } \
#       if/when/always { expr/stmt }
#       claim [expr]/map [mapping]/[code]
#
# Errors thrown from rules are logged by the calling application.
# 
# A rule can be returned from in one of two ways:
#
#   1.  Using "return" (or letting the function terminate normally)
#
#           This method will record the optional parameter to the m# output log and save the
#           output m#tags.  Errors are generated if outputs are not set.
#
#   2.  Using "exception"
#
#           Indicates that the input represents an exception to the rule, so the rule should
#           not have its outputs processed.  The optional parameter will be added to the m#
#           output log.  No errors are generated.
#
#---------------------------------------------------------------------------------------------------
proc rule {args} { ::mash::rule $args } 

proc exception {{msg {}}} { return -code break $msg }

#---------------------------------------------------------------------------------------------------
#using {
#    in  {cfg}
#    out {cfg_name_root cfg_type}
#} define {
#    rule when {string match "proj_a*.cfg" ${cfg}} then { return {proj a} }
#    rule when {string match "proj_b*.cfg" ${cfg}} then { return {proj b} }
#}
#---------------------------------------------------------------------------------------------------
proc using {args} { ::mash::using $args }


#------------------------------------------------------------------------------- 
# Parses the syntax of the "rule" command in the mashtag language.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc metric {args} { }

#------------------------------------------------------------------------------- 
# Returns the full path to the current rule file
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc rule_file {} { error "[info level 0] - not overridden" }

#------------------------------------------------------------------------------- 
# Returns the full name of the rule being evaluated 
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc rule_name {} { error "[info level 0] - not overridden" }

#------------------------------------------------------------------------------- 
# Returns the path to a file, relative to the directory that contains the
# current rule file.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc rule_relative_path {args} {
    return [file normalize [eval file join [rule_file] .. $args]]
}

#------------------------------------------------------------------------------- 
# Returns a path relative to the current object on which rules are being
# evaluated.
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc object_relative_path {args} { error "[info level 0] - not overridden" }

#------------------------------------------------------------------------------- 
# Returns 1 if mhash property doesn't exist on the current object
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc missing {varname} { expr {![has $varname]} }

#------------------------------------------------------------------------------- 
# Returns 1 if a mhash property exists on the current object
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc has {varname} { error "[info level 0] - not overridden" }


