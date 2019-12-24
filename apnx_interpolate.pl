#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use JSON;

my ($buf, $inp, $incr, $n, $nmaps, $out, @outloc, $med, $pmap, @pnloc, $pos);
my (@entries, @types, @pns, @newents, @newmaps, @newtypes, $maplen, @newpns);
my $div = 5; my $entry = 0; my $ipos = 0; my $opos=0; my @delts; my $newent=0;
GetOptions(
           "dev=i" => \$div,
           "inp=s" => \$inp,
           "out=s" => \$out,
          );
die "Divisor must be integer less than 11" if $div > 10;
my $mult = 1.0 / $div;
my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, @misc) = stat($inp)
or die "Can't stat input file: '$inp'.\n";
if ($inp) { open FHinp, $inp or die "Can't open $inp for reading"; }
else { die "required input apnx file name missing"; }
#if ($out) { open FHout, '>', $out or die "Can't open $out for writing"; }
#else { die "required ouput apnx file name missing"; }
$n = read FHinp, $buf, $size;
close FHinp;
die "Only read $n of $size" if $n ne $size;
die "Not an apnx file" if (my $fid = unpack('N', substr($buf, 0, 4))) != 65537;
my $nextstart = unpack('N', substr($buf, 4, 4));
my $len_h1 = unpack('N', substr($buf, 8, 4));
my $hdr1 = substr($buf, 12, $len_h1); $pos = 12 + $len_h1;
my $un1 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $len_h2 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $page_count = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $un32 = unpack('n', substr($buf, $pos, 2)); $pos += 2;
my $hdr2 = substr($buf, $pos, $len_h2); $pos += $len_h2;
my %h2 = %{decode_json($hdr2)};
my $pagemap = $h2{pageMap};
$pagemap =~ s/\),/)\t/g; $pagemap =~ s/\(//g; $pagemap =~ s/\)//g;
my @pmaps = split /\t/, $pagemap;
$delts[0] = 0;
for (my $i=0; $i<$page_count; $i++) {
  $pnloc[$i] = unpack('N', substr($buf, $pos, 4)); $pos += 4;
  $delts[$i] = $pnloc[$i] - $pnloc[$i-1] if $i;
}
my @sorted = sort { $a <=> $b } @delts;
my $mid = int @sorted/2;
if (@sorted%2) { $med = $sorted[$mid]; }
else { $med = ($sorted[$mid-1] + $sorted[$mid])/2; }
printf "med: $med\t%d\t%d\n", $sorted[$mid-1], $sorted[$mid];
while ($pnloc[$ipos] == 0) { $ipos++; }
for (my $i=0; $i<=$#pmaps; $i++) {
  ($entries[$i], $types[$i], $pns[$i]) = split /,/, $pmaps[$i];
}
for (my $i=0; $i<=$#pmaps; $i++) {
  if ($i<$#pmaps) {
    $maplen = $entries[$i+1] - $entries[$i];
  }
  else { $maplen = $page_count - $entries[$i]; }
  if ($types[$i] eq "a") {
print "type 'a' $pmaps[$i], maplen $maplen pages\n";
    my $loc = $pnloc[$ipos];
    $entry = $entries[$i];
    for (my $map=0; $map<$maplen; $map++, $entry++, $ipos++, $newent++) {
      $newents[$newent] = $entry;
      $newtypes[$newent] = 'c';
      $newpns[$newent] = '';
      my $fp = 0;
      if ($delts[$entry]<$med) { $incr = int(0.5 + $med/$div); }
      else { $incr = int(0.5 + $delts[$entry]/$div); }
print "incr: $incr, delt: $delts[$entry], entry $entry, i: $i, map: $map\n";
      while ($loc<$pnloc[$entry]) {
        my $pn = $entry + $fp/$div;
        $newpns[$newent] .= "$pn|";
printf "$ipos\t$pnloc[$ipos]\t$loc\t%.2f\n", $pn;
        $outloc[$opos++] = $loc;
        $loc += $incr; $fp++;
      }
      chop $newpns[$newent];
printf "($newents[$newent],$newtypes[$newent],$newpns[$newent])\n";
    }
  } elsif ($types[$i] eq "r") {
print "type 'r' $pmaps[$i], maplen $maplen pages\n";
    
  } elsif ($types[$i] eq "c") {
print "type 'c' $pmaps[$i], maplen $maplen pages\n";
    
  } else { warn "Bad page type '$types[$i]'"; }
}
printf "($entries[$#pmaps],$types[$#pmaps],$pns[$#pmaps]), %d, %d, %s%d, %d\n",
       $#pmaps, $ipos, 'page count: ', $page_count, $#pnloc;
