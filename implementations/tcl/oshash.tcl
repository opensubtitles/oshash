#!/usr/bin/env tclsh
# OpenSubtitles Hash (OSHash) - Tcl implementation.
# hash = file_size + sum_uint64_le(first 64KB) + sum_uint64_le(last 64KB),
# wrapping at 64 bits. Tcl integers are arbitrary precision, so each step is
# masked back to 64 bits with $mask.

set mask 0xFFFFFFFFFFFFFFFF

proc oshash {path} {
    global mask
    set size [file size $path]

    set fd [open $path rb]
    set first [read $fd 65536]
    set offset [expr {$size - 65536}]
    if {$offset < 0} { set offset 0 }
    seek $fd $offset
    set last [read $fd 65536]
    close $fd

    set hash [expr {$size & $mask}]
    foreach chunk [list $first $last] {
        # w = 64-bit little-endian; masking makes signed/unsigned equivalent.
        binary scan $chunk w* words
        foreach w $words {
            set hash [expr {($hash + $w) & $mask}]
        }
    }

    # Format as 16 lowercase hex digits via two 32-bit halves (portable across
    # Tcl versions for values above the signed 64-bit range).
    set hi [expr {($hash >> 32) & 0xFFFFFFFF}]
    set lo [expr {$hash & 0xFFFFFFFF}]
    return [format %08x%08x $hi $lo]
}

if {$argc < 1} {
    puts stderr "Usage: oshash.tcl <file>"
    exit 1
}
puts [oshash [lindex $argv 0]]
