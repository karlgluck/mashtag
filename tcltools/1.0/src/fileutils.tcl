####################################################################################################
#
#  This script contains extensions that help read, write and manage files
#
#  Authors:
#    Karl Gluck
#
#---------------------------------------------------------------------------------------------------
namespace eval tcltools {}
namespace eval _tcltools {}


#--------------------------------------------------------------------------------------------------- 
# Creates a temporary directory that is deleted when the calling procedure exits.
#
# Authors:
#   Karl Gluck
#--------------------------------------------------------------------------------------------------- 
proc fmake_tmp_dir {{tmp /tmp}} {

    # Generate a unique name
    set name "${::env(USER)}[pid][info level][clock clicks]"

    # Pick the directory location
    set dir [file join $tmp $name]

    # Generate the directory
    file mkdir $dir

    # Write some code to delete the directory when the caller exits
    set xbody [string map [list "__@name" $name "__@dir" $dir] {
        set __@name {}
        trace variable __@name u {
            file delete -force -- __@dir
        }
    }]
    uplevel 1 $xbody

    # Return a path to this new directory
    return $dir
}

#--------------------------------------------------------------------------------------------------- 
# Creates a temporary file that is deleted when the calling procedure exits.
#
# Authors:
#   Karl Gluck
#--------------------------------------------------------------------------------------------------- 
proc fmake_tmp_file {{tmp /tmp}} {

    # Generate a unique name
    set name "${::env(USER)}[pid][info level][clock clicks]"

    # Pick the directory location
    set path [file join $tmp $name]

    # Write some code to delete the directory when the caller exits
    set xbody [string map [list "__@name" $name "__@file" $path] {
        set __@name {}
        trace variable __@name u {
            file delete -force -- __@file
        }
    }]
    uplevel 1 $xbody

    # Return a path to this new directory
    return $path
}


#--------------------------------------------------------------------------------------------------- 
# Fills lines_var with lines from the input file.  Reads block_size bytes at
# a time.  This is MUCH faster than calling 'gets' repeatedly for files with
# many lines.
#
# Returns 0 if no more lines are read.
#
# The input file pointer (fp) must be seek-able.  Don't use this if the FP
# was a pipe, for example.
#
# Authors:
#   Karl Gluck
#--------------------------------------------------------------------------------------------------- 
proc fget_lines {fp lines_var {block_size 512000}} {
    upvar $lines_var lines

    if {[eof $fp]} {
        set lines [list]
        return 0
    }
    
    # Read the next $block_size bytes from the data
    set read_data [read $fp $block_size]

    # Find the last EOL and move the marker backward so we read it next time
    set split_point [string last "\n" $read_data]
    if {[string length $read_data] == $block_size} {
        if {[catch {
            seek $fp [expr {-($block_size - $split_point) + 1}] "current"
        }]} {
            error "fget_lines used on an unseekable file pointer"
        }
    }
 
    # Convert to list, remove (potentially incomplete) last element
    set lines [lreplace [split $read_data "\n"] end end]

    return 1
}



#---------------------------------------------------------------------------------------------------
# Runs a loop, setting the 'line' variable to each line of a file.  This
# uses batch file reading, so it is much faster than repeatedly calling 'fgets'
#
# Example usage:
#
#       fforeach_line line $fp {
#           # ... do line processing ...
#           if { $condition } then break
#           # stuff like this works, too
#           puts "at position [tell $fp] in file"
#       }
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fforeach_line {line_var_name fp code} {
    upvar $line_var_name line
    while {[fget_lines $fp lines]} {
        foreach line $lines {
            switch -- [catch {uplevel 1 $code} msg] {
            0 {
                # code ended normally
              }
            1 {
                # error
                return -code 1 $msg
            }
            2 {
                # "return"
                return -code 2 $msg
              }
            3 {
                # break
                return
              }
            4 {
                # continue
            }
            }
        }
    }
}



#---------------------------------------------------------------------------------------------------
# Returns the size of the file referenced by fp in bytes.
# File must be seekable, or this will return -1.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fsize {fp} {
    if {[catch {
        set origin [tell $fp]
        seek $fp 0 "end"
        set file_size [tell $fp]
        seek $fp $origin "start"
    }]} {
        set file_size -1
    }
    return $file_size
}




#---------------------------------------------------------------------------------------------------
# Adds a new path to be read to the batch mode of 'fread'.  After adding a bunch
# of paths using "fread_nonblocking_dispatch", use "fread_nonblocking_collect"
# to wait for all of the files to be read and obtain their contents as an
# array. 
#
# Each call opens a new file descriptor, so you may want to call this in
# smaller batches.  Reading at least 1000 files at a time seems fine in testing,
# but do your own experiments too.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fread_nonblocking_dispatch {paths} {
    confirm {![info exists ::_fread_nonblocking.vwait]} else {
        # the vwait condition is in the process of being satisfied; don't allow this addition
        return
    }
    foreach path $paths {
        set channel [open $path "r"]
        lappend ::_fread_nonblocking.data(*) $channel
        set ::_fread_nonblocking.paths($channel) $path
        fconfigure $channel -blocking 0 -translation lf 
        fileevent $channel readable [list _fread_nonblocking.getdata $channel]
    }
}


#---------------------------------------------------------------------------------------------------
# Returns an array (alternating key-value pairs in a list compatible with
# 'array set') for each path passed to fread_nonblocking_dispatch.
#
# Authors:
#   Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fread_nonblocking_collect {} {

    # Nothing to wait for? We're done.
    if {![info exists ::_fread_nonblocking.data] || [lempty ::_fread_nonblocking.data(*)]} { return {} }

    # Wait for the read to complete
    vwait {::_fread_nonblocking.vwait}
    unset {::_fread_nonblocking.vwait}

    # Grab the data that was read
    set retval [list]
    foreach {channel value} [array get ::_fread_nonblocking.data] {
        lappend retval [set ::_fread_nonblocking.paths($channel)] $value
    }
    unset ::_fread_nonblocking.data ::_fread_nonblocking.paths

    # Return the set of files
    return $retval
}

proc _fread_nonblocking.getdata {channel} {
    upvar #0 _fread_nonblocking.data data
    if {[eof $channel]} {
        close $channel

        # remove this nonblocking read from the global set
        set index [lsearch -exact $data(*) $channel]
        confirm {$index >= 0} then { 
            set data(*) [lreplace $data(*) $index $index]
        }

        # if there are no other reads outstanding, the wait condition is fulfilled
        if {[lempty $data(*)]} {
            unset ::_fread_nonblocking.data(*)
            set ::_fread_nonblocking.vwait "completed"
        }

        return
    }


    # append newly read data to the existing data
    set var data($channel)
    set new_data [read -nonewline $channel]
    set old_data [expr {[info exists $var] ? [set $var] : {}}]
    set $var "${old_data}${new_data}"
}

 
#---------------------------------------------------------------------------------------------------
# Reads the contents of a file
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fread {filename} {
    set result {}
    catch {
        set fp [open $filename]
        set result [read -nonewline $fp]
        close $fp
    }
    return $result
}


#---------------------------------------------------------------------------------------------------
# Reads lines into a list from a file
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fread_lines {filename} {
    return [split [fread $filename] "\n"]
}
 

#---------------------------------------------------------------------------------------------------
# Reads binary data from a file
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fread_binary {filename} {
    set result {}
    catch {
        set fp [open $filename]
        fconfigure $fp -translation binary
        set result [read $fp]
        close $fp
    }
    return $result
}


#---------------------------------------------------------------------------------------------------
# Adds one or more strings to the end of a file
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fappend {filename args} {
    set fp [open $filename a]
    catch { foreach str $args { puts $fp $str } }
    close $fp
}


#---------------------------------------------------------------------------------------------------
# Overwrites a file with one or more strings
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fwrite {filename args} {
    set fp [open $filename w]
    catch { foreach str $args { puts $fp $str } }
    close $fp
}


#---------------------------------------------------------------------------------------------------
# Overwrites a file with lines from one or more lists
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fwrite_lines {filename args} {
    set fp [open $filename w]
    catch { foreach str $args { puts $fp [join $str \n] } }
    close $fp
}


#---------------------------------------------------------------------------------------------------
# Overwrites a file with binary data from one or more arguments
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc fwrite_binary {filename args} {
    catch {
        set fp [open $filename w]
        fconfigure $fp -translation binary
        catch { foreach str $args { puts -nonewline $fp $str } }
        close $fp
    }
}


#---------------------------------------------------------------------------------------------------
# Returns the full path to a file
#
#  Authors:
#    Karl Gluck
#---------------------------------------------------------------------------------------------------
proc realpath {path} {
    set path [file normalize [file join [pwd] $path]]
    set sp [file split $path]
    set rb {/}
    foreach f $sp {
        set joined [file join $rb $f]
        if {[catch {set link [file readlink $joined]}]} {
            set rb $joined
        } else {
            set rb [file join $rb $link]
        }
        set rb [file normalize $rb]
    }
    return $rb
}


