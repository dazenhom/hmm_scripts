#!/usr/bin/perl
#
# pdf格式转换工具
#
# Usage:
#       perl convert_dur.pl <src dir> <des dir> <tree num>
#

use strict;
use warnings;

##############################################################################

my $loglv = 0;
my @args = @ARGV;
if(scalar(@args) != 3){
	print STDERR "\nUsage:";
	print STDERR "\n      perl convert_dur.pl <src dir> <des dir> <tree num>";
	print STDERR "\n\n";
	exit(-1);
}

&convert_dur_pdf(@args);
&convert_dur_tre(@args);

exit(0);

##############################################################################

sub convert_dur_pdf{
	my $srcdir= shift;
	my $desdir= shift;
	my $ntree = shift;

	my $savfn = "$desdir/dur.pdf";
	my $vsize = 1;

	# read data
	my (@leaf,@mean,@vari);
	for(my $i = 0; $i < $ntree; $i ++){
		my $pdffn = sprintf "$srcdir/dur.pdf.%d", $i+1;
		open INPUT,  "$pdffn"  or die "cannot open file : $pdffn\n";
		my @STAT = stat(INPUT);
		my $data;
		read INPUT, $data, $STAT[7];
		close INPUT;
	
		my $skip = 0;
		push @leaf, unpack "x${skip}i1", $data; $skip += 4;
		if($loglv){
			print "file=$pdffn\nsize=$STAT[7]\nvsize=$vsize\nleaf=$leaf[-1]\n";
		}
		# mean/vari
		my @data = unpack "x${skip}f*", $data;
		for(my $j = 0; $j < $leaf[$i]; $j ++){
			for(my $k = 0; $k < $vsize; $k ++){
				my $mean = shift @data;
				$mean[$i][$j][$k] = $mean;
			}
			for(my $k = 0; $k < $vsize; $k ++){
				my $vari = shift @data;
				$vari[$i][$j][$k] = $vari;
			}
		}
		if($loglv){
		        for(my $j = 0; $j < $leaf[$i]; $j ++){
				for(my $k = 0; $k < $vsize; $k ++){
					print "mean[$i][$j][$k]=$mean[$i][$j][$k]\n";
					print "vari[$i][$j][$k]=$vari[$i][$j][$k]\n";
				}
			}
		}
	}

	# write data
	open OUTPUT, ">$savfn" or die "cannot open file : $savfn\n"; binmode OUTPUT;
	# header data
	my $data = pack "N1", $vsize;
	print OUTPUT $data;
	for(my $i = 0; $i < $ntree; $i ++){
		$data = pack "N1", $leaf[$i];
		print OUTPUT $data;
	}
	# body data
	for(my $i = 0; $i < $ntree; $i ++){
		for(my $j = 0; $j < $leaf[$i]; $j ++){
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
		}
	}
	close OUTPUT;
}

sub convert_dur_tre{
	my $srcdir= shift;
	my $desdir= shift;
	my $ntree = shift;

	my $savfn = "$desdir/tree-dur.inf";

	# load tree
        my (%hqs,$str);
        for(my $i = 0; $i < $ntree; $i ++){
                my $trefn = sprintf "$srcdir/tree-dur.inf.%d", $i+1;
                open INPUT,  "$trefn"  or die "cannot open file : $trefn\n";
		while(<INPUT>){
			next if(/^$/);
			if(/QS/){
				$hqs{$_}++;
			}elsif(/{\*}\[2\]/){
				$str .= sprintf "{*}[%d]\n", 2+$i;
			}else{
				$str .= $_;
			}
		}
		close INPUT;
	}

	# wirte tree
	open OUTPUT, ">$savfn" or die "cannot open file : $savfn\n";
	foreach my $qs(keys %hqs){
		print OUTPUT $qs;
	}
	print OUTPUT $str;
	print OUTPUT "\n";
	close OUTPUT;
}




