#!/usr/bin/perl
#
# pdf格式转换工具
#
# Usage:
#       perl pdf_convert.pl <input file> <output file> <tree number> <vector size> <msd>
#

use strict;
use warnings;

##############################################################################

my $loglv = 0;
my @args = @ARGV;
if(scalar(@args) != 5){
  print STDERR "\nUsage:";
  print STDERR "\n      perl pdf_convert.pl <input file> <output file> <tree number> <vector size> <msd>";
  print STDERR "\n\n";
  exit(-1);
}

&convert_pdf(@args);

exit(0);

##############################################################################

sub convert_pdf{
  my $pdffn = shift;
  my $savfn = shift;
  my $ntree = shift;
  my $vsize = shift;
  my $msd   = shift;

  # read data
  open INPUT,  "$pdffn"  or die "cannot open file : $pdffn\n";
  my @STAT = stat(INPUT);
  my $data;
  read INPUT, $data, $STAT[7];
  close INPUT;

  # @bc299: This might cause error in different michines. 20180130
  my @data = unpack "N*", $data;
  $data = pack "V*", @data;

  my $skip = 0;
  # tree size
  my @leaf;
  for(my $i = 0; $i < $ntree; $i ++){
    push @leaf, unpack "x${skip}i1", $data; $skip += 4;
  }
  if($loglv){
    print "file=$pdffn\nsize=$STAT[7]\nmsd=$msd\nvsize=$vsize\nleaf=@leaf\n";
  }
  # mean/vari
  my @data = unpack "x${skip}f*", $data;
  my (@mean,@vari,@vw,@uvw);
  for(my $i = 0; $i < $ntree; $i ++){
    for(my $j = 0; $j < $leaf[$i]; $j ++){
      for(my $k = 0; $k < $vsize; $k ++){
        my $mean = shift @data;
        $mean[$i][$j][$k] = $mean;
      }
      for(my $k = 0; $k < $vsize; $k ++){
        my $vari = shift @data;
        $vari[$i][$j][$k] = $vari;
      }
      if($msd){
        my $vw  = shift @data;
        for(my $k = 0; $k < $vsize; $k ++){
          $vw[$i][$j][$k]  = $vw;
          $uvw[$i][$j][$k] = 1.0 - $vw;
        }
      }
    }
  }
  if($loglv){
    for(my $i = 0; $i < $ntree; $i ++){
                  for(my $j = 0; $j < $leaf[$i]; $j ++){
        for(my $k = 0; $k < $vsize; $k ++){
          print "mean[$i][$j][$k]=$mean[$i][$j][$k]\n";
          print "vari[$i][$j][$k]=$vari[$i][$j][$k]\n";
          print "vw[$i][$j][$k]=$vw[$i][$j][$k],uvw[$i][$j][$k]=$uvw[$i][$j][$k]\n" if(defined $vw[$i][$j][$k]);
        }
      }
    }
  }

  # write data
  open OUTPUT, ">$savfn" or die "cannot open file : $savfn\n"; binmode OUTPUT;
  # header data
  $data = pack "N1", $vsize;
  print OUTPUT $data;
  for(my $i = 0; $i < $ntree; $i ++){
    $data = pack "N1", $leaf[$i];
    print OUTPUT $data;
  }
  # body data
  for(my $i = 0; $i < $ntree; $i ++){
    for(my $j = 0; $j < $leaf[$i]; $j ++){
      if($msd){
        for(my $k = 0; $k < $vsize; $k ++){
          $data = $mean[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
          $data = $vari[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
          $data = $vw[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
          $data = $uvw[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
        }
      }else{
        for(my $k = 0; $k < $vsize; $k ++){
          $data = $mean[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
        }
        for(my $k = 0; $k < $vsize; $k ++){
          $data = $vari[$i][$j][$k];
          $data = pack "f1",   $data;
          $data = unpack "V1", $data;
          $data = pack "N1",   $data;
          print OUTPUT $data;
        }
      }# msd
    }
  }
  close OUTPUT;
}

