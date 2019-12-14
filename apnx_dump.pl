#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my ($buf, $dif, $inp, $mark, $n, $off, @pnloc, $pos, $raw);
GetOptions(
           "inp=s" => \$inp,
           "off=i" => \$off,
           "raw=s" => \$raw
          );
if ($raw) {
  open FHraw, $raw or die "Can't open $raw for reading";
  if ($raw =~ /assembled_text/) { $off = 0; } else { $off = 14 unless $off; }
}
my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, @misc) = stat($inp)
or die "Can't stat input file: '$inp'.\n";
if ($inp) { open FHinp, $inp or die "Can't open $inp for reading"; }
else { die "required apnx file name missing"; }
$n = read FHinp, $buf, $size;
close FHinp;
die "Only read $n of $size" if $n ne $size;
die "Not an apnx file" if (my $fid = unpack('N', substr($buf, 0, 4))) != 65537;
my $nextstart = unpack('N', substr($buf, 4, 4));
my $len_h1 = unpack('N', substr($buf, 8, 4));
print "# FID: $fid, next_start: $nextstart, hdr1len: $len_h1\n";
my $hdr1 = substr($buf, 12, $len_h1); $pos = 12 + $len_h1;
print "# hdr1:\n# $hdr1\n";
my $un1 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $len_h2 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $page_count = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $un32 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
print "# un1: $un1, hdr2len: $len_h2, page count: $page_count, un32: $un32\n";
my $hdr2 = substr($buf, $pos, $len_h2); $pos += $len_h2;
print "# hdr2:\n# ${hdr2}\n";
for (my $i=0; $i<$page_count; $i++) {
  $pnloc[$i] = unpack('N', substr($buf, $pos, 4)); $pos += 4;
  if ($i) { $dif = $pnloc[$i] - $pnloc[$i-1]; } else { $dif = 0; }
  if ($raw) {
    seek FHraw, $pnloc[$i] + $off, 0;
    $n = read FHraw, $mark, 16;
    print "$i\t$pnloc[$i]\t$dif\t$mark\n";
  } else { print "$i\t$pnloc[$i]\t$dif\n"; }
}
