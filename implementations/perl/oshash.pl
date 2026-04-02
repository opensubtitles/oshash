#!/usr/bin/perl
# OpenSubtitles Hash (OSHash) - Perl implementation.
use strict;
use warnings;

sub compute_hash {
    my $filename = shift or die "Need filename";
    open my $handle, "<:raw", $filename or die "Cannot open $filename: $!";
    my $fsize = -s $filename;

    my $hash = [$fsize & 0xFFFF, ($fsize >> 16) & 0xFFFF, 0, 0];

    $hash = add_uint64($hash, read_uint64($handle)) for (1..8192);

    my $offset = $fsize - 65536;
    seek($handle, $offset > 0 ? $offset : 0, 0) or die $!;

    $hash = add_uint64($hash, read_uint64($handle)) for (1..8192);

    close $handle or die $!;
    return uint64_format_hex($hash);
}

sub read_uint64 {
    read($_[0], my $u, 8);
    return [unpack("vvvv", $u)];
}

sub add_uint64 {
    my $o = [0, 0, 0, 0];
    my $carry = 0;
    for my $i (0..3) {
        my $sum = $_[0]->[$i] + $_[1]->[$i] + $carry;
        if ($sum > 0xffff) {
            $o->[$i] += $sum & 0xffff;
            $carry = 1;
        } else {
            $o->[$i] += $sum;
            $carry = 0;
        }
    }
    return $o;
}

sub uint64_format_hex {
    return sprintf("%04x%04x%04x%04x", $_[0]->[3], $_[0]->[2], $_[0]->[1], $_[0]->[0]);
}

die "Usage: $0 <file>\n" unless @ARGV;
print compute_hash($ARGV[0]), "\n";
