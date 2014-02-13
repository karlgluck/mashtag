#------------------------------------------------------------------------------- 
# Sends an HTML email.  Attachments are supported.
#
# "attachments" is a list where each element contains a list of:
#   content type - For example, "text/html"
#   name - Name of the file being attached
#   contents - What to put in the attachment's body
#
# Authors:
#   Karl Gluck
#------------------------------------------------------------------------------- 
proc send_email {to subject html_message from {attachments {}}} {

    # clean from/to
    set to [regsub -all {\s} $to " "]
    set from [regsub -all {\s} $from " "]
    set subject [regsub -all {\s} $subject " "]

    set boundary "_----------=_10167391557129230"

    # Build the MIME-encoded email
    set body [format {From: %s
To: %s
Subject: %s
Content-Type: multipart/mixed; boundary="%s"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
--%s
Content-Transfer-Encoding: 7bit
Content-Type: text/html

%s

--%s} $from [string trim $to] $subject $boundary $boundary [string trim $html_message] $boundary]

    foreach attachment $attachments {
        lassign $attachment content_type name contents
        append body [format {
Content-Transfer-Encoding: BASE64
Content-Type: %s; name="%s"

%s

--%s} $content_type $name [::base64::encode $contents] $boundary]
    }

    append body "--"

    set fp [open "| sendmail -oi -t" w]
    puts $fp $body
    close $fp
}

# From:
# http://www.opensource.apple.com/source/tcl/tcl-87/tcl_ext/tcllib/tcllib/modules/base64/base64.tcl
#
# This software is copyrighted by Ajuba Solutions and other parties.
# The following terms apply to all files associated with the software unless
# explicitly disclaimed in individual files.
# 
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
# 
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal 
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license. 
# base64.tcl --
#
# Encode/Decode base64 for a string
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# The decoder was done for exmh by Chris Garrigues
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: base64.tcl,v 1.29 2008/05/28 17:34:31 andreas_kupries Exp $

# Version 1.0   implemented Base64_Encode, Base64_Decode
# Version 2.0   uses the base64 namespace
# Version 2.1   fixes various decode bugs and adds options to encode
# Version 2.2   is much faster, Tcl8.0 compatible
# Version 2.2.1 bugfixes
# Version 2.2.2 bugfixes
# Version 2.3   bugfixes and extended to support Trf
namespace eval base64 {
	variable base64 {}
	variable base64_en {}

	# We create the auxiliary array base64_tmp, it will be unset later.

	set i 0
	foreach char {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
		a b c d e f g h i j k l m n o p q r s t u v w x y z \
		0 1 2 3 4 5 6 7 8 9 + /} {
	    set base64_tmp($char) $i
	    lappend base64_en $char
	    incr i
	}

	#
	# Create base64 as list: to code for instance C<->3, specify
	# that [lindex $base64 67] be 3 (C is 67 in ascii); non-coded
	# ascii chars get a {}. we later use the fact that lindex on a
	# non-existing index returns {}, and that [expr {} < 0] is true
	#

	# the last ascii char is 'z'
	scan z %c len
	for {set i 0} {$i <= $len} {incr i} {
	    set char [format %c $i]
	    set val {}
	    if {[info exists base64_tmp($char)]} {
		set val $base64_tmp($char)
	    } else {
		set val {}
	    }
	    lappend base64 $val
	}

	# code the character "=" as -1; used to signal end of message
	scan = %c i
	set base64 [lreplace $base64 $i $i -1]

	# remove unneeded variables
	unset base64_tmp i char len val

	namespace export encode decode
    }

    # ::base64::encode --
    #
    #	Base64 encode a given string.
    #
    # Arguments:
    #	args	?-maxlen maxlen? ?-wrapchar wrapchar? string
    #	
    #		If maxlen is 0, the output is not wrapped.
    #
    # Results:
    #	A Base64 encoded version of $string, wrapped at $maxlen characters
    #	by $wrapchar.
    
    proc ::base64::encode {args} {
	set base64_en $::base64::base64_en
	
	# Set the default wrapchar and maximum line length to match
	# the settings for MIME encoding (RFC 3548, RFC 2045). These
	# are the settings used by Trf as well. Various RFCs allow for
	# different wrapping characters and wraplengths, so these may
	# be overridden by command line options.
	set wrapchar "\n"
	set maxlen 76

	if { [llength $args] == 0 } {
	    error "wrong # args: should be \"[lindex [info level 0] 0]\
		    ?-maxlen maxlen? ?-wrapchar wrapchar? string\""
	}

	set optionStrings [list "-maxlen" "-wrapchar"]
	for {set i 0} {$i < [llength $args] - 1} {incr i} {
	    set arg [lindex $args $i]
	    set index [lsearch -glob $optionStrings "${arg}*"]
	    if { $index == -1 } {
		error "unknown option \"$arg\": must be -maxlen or -wrapchar"
	    }
	    incr i
	    if { $i >= [llength $args] - 1 } {
		error "value for \"$arg\" missing"
	    }
	    set val [lindex $args $i]

	    # The name of the variable to assign the value to is extracted
	    # from the list of known options, all of which have an
	    # associated variable of the same name as the option without
	    # a leading "-". The [string range] command is used to strip
	    # of the leading "-" from the name of the option.
	    #
	    # FRINK: nocheck
	    set [string range [lindex $optionStrings $index] 1 end] $val
	}
    
	# [string is] requires Tcl8.2; this works with 8.0 too
	if {[catch {expr {$maxlen % 2}}]} {
	    return -code error "expected integer but got \"$maxlen\""
	} elseif {$maxlen < 0} {
	    return -code error "expected positive integer but got \"$maxlen\""
	}

	set string [lindex $args end]

	set result {}
	set state 0
	set length 0


	# Process the input bytes 3-by-3

	binary scan $string c* X

	foreach {x y z} $X {
	    ADD [lindex $base64_en [expr {($x >>2) & 0x3F}]]
	    if {$y != {}} {
		ADD [lindex $base64_en [expr {(($x << 4) & 0x30) | (($y >> 4) & 0xF)}]]
		if {$z != {}} {
		    ADD [lindex $base64_en [expr {(($y << 2) & 0x3C) | (($z >> 6) & 0x3)}]]
		    ADD [lindex $base64_en [expr {($z & 0x3F)}]]
		} else {
		    set state 2
		    break
		}
	    } else {
		set state 1
		break
	    }
	}
	if {$state == 1} {
	    ADD [lindex $base64_en [expr {(($x << 4) & 0x30)}]]
	    ADD =
	    ADD =
	} elseif {$state == 2} {
	    ADD [lindex $base64_en [expr {(($y << 2) & 0x3C)}]]
	    ADD =
	}
	return $result
    }

    proc ::base64::ADD {x} {
	# The line length check is always done before appending so
	# that we don't get an extra newline if the output is a
	# multiple of $maxlen chars long.

	upvar 1 maxlen maxlen length length result result wrapchar wrapchar
	if {$maxlen && $length >= $maxlen} {
	    append result $wrapchar
	    set length 0
	}
	append result $x
	incr length
	return
    }

    # ::base64::decode --
    #
    #	Base64 decode a given string.
    #
    # Arguments:
    #	string	The string to decode.  Characters not in the base64
    #		alphabet are ignored (e.g., newlines)
    #
    # Results:
    #	The decoded value.

    proc ::base64::decode {string} {
	if {[string length $string] == 0} {return ""}

	set base64 $::base64::base64
	set output "" ; # Fix for [Bug 821126]

	binary scan $string c* X
	foreach x $X {
	    set bits [lindex $base64 $x]
	    if {$bits >= 0} {
		if {[llength [lappend nums $bits]] == 4} {
		    foreach {v w z y} $nums break
		    set a [expr {($v << 2) | ($w >> 4)}]
		    set b [expr {(($w & 0xF) << 4) | ($z >> 2)}]
		    set c [expr {(($z & 0x3) << 6) | $y}]
		    append output [binary format ccc $a $b $c]
		    set nums {}
		}		
	    } elseif {$bits == -1} {
		# = indicates end of data.  Output whatever chars are left.
		# The encoding algorithm dictates that we can only have 1 or 2
		# padding characters.  If x=={}, we have 12 bits of input 
		# (enough for 1 8-bit output).  If x!={}, we have 18 bits of
		# input (enough for 2 8-bit outputs).
		
		foreach {v w z} $nums break
		set a [expr {($v << 2) | (($w & 0x30) >> 4)}]
		if {$z == {}} {
		    append output [binary format c $a ]
		} else {
		    set b [expr {(($w & 0xF) << 4) | (($z & 0x3C) >> 2)}]
		    append output [binary format cc $a $b]
		}		
		break
	    } else {
		# RFC 2045 says that line breaks and other characters not part
		# of the Base64 alphabet must be ignored, and that the decoder
		# can optionally emit a warning or reject the message.  We opt
		# not to do so, but to just ignore the character. 
		continue
	    }
	}
	return $output
}
