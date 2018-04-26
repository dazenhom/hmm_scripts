#!/usr/bin/perl
# ----------------------------------------------------------------- #
#           The HMM-Based Speech Synthesis System (HTS)             #
#           developed by HTS Working Group                          #
#           http://hts.sp.nitech.ac.jp/                             #
# ----------------------------------------------------------------- #
#                                                                   #
#  Copyright (c) 2001-2015  Nagoya Institute of Technology          #
#                           Department of Computer Science          #
#                                                                   #
#                2001-2008  Tokyo Institute of Technology           #
#                           Interdisciplinary Graduate School of    #
#                           Science and Engineering                 #
#                                                                   #
# All rights reserved.                                              #
#                                                                   #
# Redistribution and use in source and binary forms, with or        #
# without modification, are permitted provided that the following   #
# conditions are met:                                               #
#                                                                   #
# - Redistributions of source code must retain the above copyright  #
#   notice, this list of conditions and the following disclaimer.   #
# - Redistributions in binary form must reproduce the above         #
#   copyright notice, this list of conditions and the following     #
#   disclaimer in the documentation and/or other materials provided #
#   with the distribution.                                          #
# - Neither the name of the HTS working group nor the names of its  #
#   contributors may be used to endorse or promote products derived #
#   from this software without specific prior written permission.   #
#                                                                   #
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND            #
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,       #
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF          #
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE          #
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS #
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,          #
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   #
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,     #
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON #
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,   #
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY    #
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE           #
# POSSIBILITY OF SUCH DAMAGE.                                       #
# ----------------------------------------------------------------- #

$| = 1;

if ( @ARGV < 1 ) {
  print "usage: Training.pl Config.pm\n";
  exit(0);
}

# load configuration variables
require( $ARGV[0] );
use threads;

# paral tool : slurm / qsub
$slurm_qsub = system("which sbatch>/dev/null 2>&1") ? 0 : 1;

# model structure
foreach $set (@SET) {
  $vSize{$set}{'total'}   = 0;
  $nstream{$set}{'total'} = 0;
  $nPdfStreams{$set}      = 0;
  foreach $type ( @{ $ref{$set} } ) {
    $vSize{$set}{$type} = $nwin{$type} * $ordr{$type};
    $vSize{$set}{'total'} += $vSize{$set}{$type};
    $nstream{$set}{$type} = $stre{$type} - $strb{$type} + 1;
    $nstream{$set}{'total'} += $nstream{$set}{$type};
    $nPdfStreams{$set}++;
  }
}

# File locations =========================
# data directory
$datdir = "$prjdir/data";

# data location file
$scp{'trn'} = "$datdir/scp/train.scp";
$scp{'gen'} = "$datdir/scp/gen.scp";
$scp{'adp'} = "$datdir/scp/adapt.scp";

# model list files
$lst{'mon'} = "$datdir/lists/mono.list";
$lst{'ful'} = "$datdir/lists/full.list";
$lst{'all'} = "$datdir/lists/full_all.list";

# master label files
$mlf{'mon'} = "$datdir/labels/mono.mlf";
$mlf{'ful'} = "$datdir/labels/full.mlf";

# configuration variable files
$cfg{'trn'} = "$prjdir/configs/qst${qnum}/ver${ver}/trn.cnf";
$cfg{'nvf'} = "$prjdir/configs/qst${qnum}/ver${ver}/nvf.cnf";
$cfg{'syn'} = "$prjdir/configs/qst${qnum}/ver${ver}/syn.cnf";
$cfg{'cnv'} = "$prjdir/configs/qst${qnum}/ver${ver}/cnv.cnf";
$cfg{'apg'} = "$prjdir/configs/qst${qnum}/ver${ver}/apg.cnf";
$cfg{'stc'} = "$prjdir/configs/qst${qnum}/ver${ver}/stc.cnf";
foreach $type (@cmp) {
  $cfg{$type} = "$prjdir/configs/qst${qnum}/ver${ver}/${type}.cnf";
}
foreach $type (@dur) {
  $cfg{$type} = "$prjdir/configs/qst${qnum}/ver${ver}/${type}.cnf";
}

# configuration variable files for adaptation
$cfg{'adp'} = "$prjdir/configs/qst${qnum}/ver${ver}/adp.cnf";
$cfg{'map'} = "$prjdir/configs/qst${qnum}/ver${ver}/map.cnf";
$cfg{'aln'} = "$prjdir/configs/qst${qnum}/ver${ver}/aln.cnf";
$cfg{'sat'} = "$prjdir/configs/qst${qnum}/ver${ver}/sat.cnf";
foreach $set (@SET) {
  $cfg{'dec'}{$set} = "$prjdir/configs/qst${qnum}/ver${ver}/dec_${set}.cnf";
}

# name of proto type definition file
$prtfile{'cmp'} = "$prjdir/proto/qst${qnum}/ver${ver}/state-${nState}_stream-$nstream{'cmp'}{'total'}";
foreach $type (@cmp) {
  $prtfile{'cmp'} .= "_${type}-$vSize{'cmp'}{$type}";
}
$prtfile{'cmp'} .= ".prt";

# model files
foreach $set (@SET) {
  $model{$set}   = "$prjdir/models/qst${qnum}/ver${ver}/${set}";
  $hinit{$set}   = "$model{$set}/HInit";
  $hrest{$set}   = "$model{$set}/HRest";
  $vfloors{$set} = "$model{$set}/vFloors";
  $avermmf{$set} = "$model{$set}/average.mmf";
  $initmmf{$set} = "$model{$set}/init.mmf";
  $monommf{$set} = "$model{$set}/monophone.mmf";
  $fullmmf{$set} = "$model{$set}/fullcontext.mmf";
  $clusmmf{$set} = "$model{$set}/clustered.mmf";
  $untymmf{$set} = "$model{$set}/untied.mmf";
  $reclmmf{$set} = "$model{$set}/re_clustered.mmf";
  $rclammf{$set} = "$model{$set}/re_clustered_all.mmf";
  $spatmmf{$set} = "$model{$set}/re_clustered_sat.mmf";
  $satammf{$set} = "$model{$set}/re_clustered_sat_all.mmf";
  $tiedlst{$set} = "$model{$set}/tiedlist";
  $stcmmf{$set}  = "$model{$set}/stc.mmf";
  $stcammf{$set} = "$model{$set}/stc_all.mmf";
  $stcbase{$set} = "$model{$set}/stc.base";
}

# statistics files
foreach $set (@SET) {
  $stats{$set} = "$prjdir/stats/qst${qnum}/ver${ver}/${set}.stats";
}

# model edit files
foreach $set (@SET) {
  $hed{$set} = "$prjdir/edfiles/qst${qnum}/ver${ver}/${set}";
  $lvf{$set} = "$hed{$set}/lvf.hed";
  $m2f{$set} = "$hed{$set}/m2f.hed";
  $mku{$set} = "$hed{$set}/mku.hed";
  $unt{$set} = "$hed{$set}/unt.hed";
  $upm{$set} = "$hed{$set}/upm.hed";
  foreach $type ( @{ $ref{$set} } ) {
    $cnv{$type} = "$hed{$set}/cnv_$type.hed";
    $cxc{$type} = "$hed{$set}/cxc_$type.hed";
  }
}

# questions about contexts
foreach $set (@SET) {
  foreach $type ( @{ $ref{$set} } ) {
    $qs{$type}     = "$datdir/questions/questions_qst${qnum}.hed";
    $qs_utt{$type} = "$datdir/questions/questions_utt_qst${qnum}.hed";
  }
}

# decision tree files
foreach $set (@SET) {
  $trd{$set} = "${prjdir}/trees/qst${qnum}/ver${ver}/${set}";
  foreach $type ( @{ $ref{$set} } ) {
    $mdl{$type} = "-m -a $mdlf{$type}" if ( $thr{$type} eq '000' );
    $tre{$type} = "$trd{$set}/${type}.inf";
  }
}

# converted model & tree files for hts_engine
$voice = "$prjdir/voices/qst${qnum}/ver${ver}";
foreach $set (@SET) {
  foreach $type ( @{ $ref{$set} } ) {
    $trv{$type} = "$voice/tree-${type}.inf";
    $pdf{$type} = "$voice/${type}.pdf";
  }
}
$type       = 'lpf';
$trv{$type} = "$voice/tree-${type}.inf";
$pdf{$type} = "$voice/${type}.pdf";

# window files for parameter generation
$windir = "${datdir}/win";
foreach $type (@cmp) {
  for ( $d = 1 ; $d <= $nwin{$type} ; $d++ ) {
    $win{$type}[ $d - 1 ] = "${type}.win${d}";
  }
}
$type                 = 'lpf';
$d                    = 1;
$win{$type}[ $d - 1 ] = "${type}.win${d}";

# global variance files and directories for parameter generation
$gvdir         = "$prjdir/gv/qst${qnum}/ver${ver}";
$gvfaldir      = "$gvdir/fal";
$gvdatdir      = "$gvdir/dat";
$gvlabdir      = "$gvdir/lab";
$scp{'gv'}     = "$gvdir/gv.scp";
$mlf{'gv'}     = "$gvdir/gv.mlf";
$prtfile{'gv'} = "$gvdir/state-1_stream-${nPdfStreams{'cmp'}}";
foreach $type (@cmp) {
  $prtfile{'gv'} .= "_${type}-$ordr{$type}";
}
$prtfile{'gv'} .= ".prt";
$avermmf{'gv'} = "$gvdir/average.mmf";
$fullmmf{'gv'} = "$gvdir/fullcontext.mmf";
$clusmmf{'gv'} = "$gvdir/clustered.mmf";
$clsammf{'gv'} = "$gvdir/clustered_all.mmf";
$tiedlst{'gv'} = "$gvdir/tiedlist";
$mku{'gv'}     = "$gvdir/mku.hed";

foreach $type (@cmp) {
  $gvcnv{$type} = "$gvdir/cnv_$type.hed";
  $gvcxc{$type} = "$gvdir/cxc_$type.hed";
  $gvmdl{$type} = "-m -a $gvmdlf{$type}" if ( $gvthr{$type} eq '000' );
  $gvtre{$type} = "$gvdir/${type}.inf";
  $gvpdf{$type} = "$voice/gv-${type}.pdf";
  $gvtrv{$type} = "$voice/tree-gv-${type}.inf";
}

# files and directories for modulation spectrum-based postfilter
$mspfdir     = "$prjdir/mspf/qst${qnum}/ver${ver}";
$mspffaldir  = "$mspfdir/fal";
$scp{'mspf'} = "$mspfdir/fal.scp";
foreach $type ('mgc') {
  foreach $mspftype ( "nat", "gen/1mix/$pgtype" ) {
    $mspfdatdir{$mspftype}   = "$mspfdir/dat/$mspftype";
    $mspfstatsdir{$mspftype} = "$mspfdir/stats/$mspftype";
    for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
      $mspfmean{$type}{$mspftype}[$d] = "$mspfstatsdir{$mspftype}/${type}_dim$d.mean";
      $mspfstdd{$type}{$mspftype}[$d] = "$mspfstatsdir{$mspftype}/${type}_dim$d.stdd";
    }
  }
}
# adaptation-related files
foreach $set (@SET) {
  $regtree{$set} = "$model{$set}/regTrees";
  $xforms{$set}  = "$model{$set}/xforms";
  $mapmmf{$set}  = "$model{$set}/mapmmf";
  for $type ( 'reg', 'dec' ) {    # reg -> regression tree, dec -> decision tree
    $red{$set}{$type}   = "$hed{$set}/${type}.hed";
    $rbase{$set}{$type} = "$regtree{$set}/${type}.base";
    $rtree{$set}{$type} = "$regtree{$set}/${type}.tree";
  }
}

# HTS Commands & Options ========================
$HCompV{'cmp'} = "$HCOMPV    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -m ";
$HCompV{'gv'}  = "$HCOMPV    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'gv'}  -m ";
$HList         = "$HLIST     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -h -z ";
$HInit         = "$HINIT     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'}                -m 1 -u tmvw     -w $wf ";
$HRest         = "$HREST     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'}                -m 1 -u tmvw     -w $wf ";
$HERest{'mon'} = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -I $mlf{'mon'} -m 1 -u tmvwdmv  -w $wf -t $beam ";
$HERest{'ful'} = "$HEREST    -A -B -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -I $mlf{'ful'} -m 1 -u tmvwdmv  -w $wf -t $beam -h $spkrPat ";
$HERest{'gv'}  = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'gv'}  -I $mlf{'gv'}  -m 1 ";
$HERest{'adp'} = "$HEREST    -A -B -C $cfg{'trn'} -D -T 1 -S $scp{'adp'} -I $mlf{'ful'} -m 1 -u ada      -w $wf -t $beam -h $spkrPat ";
$HERest{'map'} = "$HEREST    -A -B -C $cfg{'trn'} -D -T 1 -S $scp{'adp'} -I $mlf{'ful'} -m 1 -u pmvwdpmv -w $wf -t $beam -h $spkrPat ";
$HHEd{'trn'}   = "$HHED      -A -B -C $cfg{'trn'} -D -T 1 -p -i ";
$HHEd{'cnv'}   = "$HHED      -A -B -C $cfg{'cnv'} -D -T 1 -p -i ";
$HSMMAlign     = "$HSMMALIGN -A    -C $cfg{'trn'} -D -T 1 -I $mlf{'mon'} -t $beam -w 1.0 ";
$HMGenS        = "$HMGENS    -A -B -C $cfg{'syn'} -D -T 1                               -t $beam ";
$HERest{'ful_modi'} = "$HEREST    -A -B -C $cfg{'trn'} -D -T 1 -I $mlf{'ful'} -m 1 -u tmvwdmv -w $wf -t $beam -h $spkrPat ";
$HERest{'mon_modi'} = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -I $mlf{'mon'} -m 1 -u tmvwdmv -w $wf -t $beam ";


# add by wwy74
$labfaldir     = "$prjdir/cuttedlab";
$htslogdir     = "$prjdir/HTSLOG";

# =============================================================
# ===================== Main Program ==========================
# =============================================================

# preparing environments
if ($MKEMV) {
  print_time("preparing environments");

  # make directories
  foreach $dir ( 'models', 'stats', 'edfiles', 'trees', 'gv', 'mspf', 'voices', 'gen', 'proto', 'configs' ) {
    mkdir "$prjdir/$dir",                      0755;
    mkdir "$prjdir/$dir/qst${qnum}",           0755;
    mkdir "$prjdir/$dir/qst${qnum}/ver${ver}", 0755;
  }
  foreach $set (@SET) {
    mkdir "$model{$set}", 0755;
    mkdir "$hinit{$set}", 0755;
    mkdir "$hrest{$set}", 0755;
    mkdir "$hed{$set}",   0755;
    mkdir "$trd{$set}",   0755;
    mkdir "$regtree{$set}", 0755;
    mkdir "$xforms{$set}",  0755;
    mkdir "$mapmmf{$set}",  0755;
  }

  # make config files
  make_config();
  make_config_regtree();
  make_config_adapt();
  make_config_sat();

  # make model prototype definition file
  make_proto();

  # add by wwy74
  mkdir $labfaldir, 0755;
  mkdir $htslogdir, 0755;
}

# HCompV (computing variance floors)
if ($HCMPV) {
  print_time("computing variance floors");

  # make average model and compute variance floors
  shell("$HCompV{'cmp'} -M $model{'cmp'} -o $avermmf{'cmp'} $prtfile{'cmp'}");
  shell("head -n 1 $prtfile{'cmp'} > $initmmf{'cmp'}");
  shell("cat $vfloors{'cmp'} >> $initmmf{'cmp'}");

  make_duration_vfloor( $initdurmean, $initdurvari );
}

# HInit & HRest (initialization & reestimation)
$align_first = 0;
Re_Align:
if ($IN_RE && !$align_first) {
  print_time("initialization & reestimation");

  mkdir $htslogdir, 0755 if(! -d $htslogdir); # add by wwy74
  if ($daem) {
    open( LIST, $lst{'mon'} ) || die "Cannot open $!";
    while ( $phone = <LIST> ) {

      # trimming leading and following whitespace characters
      $phone =~ s/^\s+//;
      $phone =~ s/\s+$//;

      # skip a blank line
      if ( $phone eq '' ) {
        next;
      }

      print "=============== $phone ================\n";
      print "use average model instead of $phone\n";
      foreach $set (@SET) {
        open( SRC, "$avermmf{$set}" )       || die "Cannot open $!";
        open( TGT, ">$hrest{$set}/$phone" ) || die "Cannot open $!";
        while ( $str = <SRC> ) {
          if ( index( $str, "~h" ) == 0 ) {
            print TGT "~h \"$phone\"\n";
          }
          else {
            print TGT "$str";
          }
        }
        close(TGT);
        close(SRC);
      }
    }
    close(LIST);
  }
  else {
    open( LIST, $lst{'mon'} ) || die "Cannot open $!";
    @jobs = (); $im = -1;
    while ( $phone = <LIST> ) {

      # trimming leading and following whitespace characters
      $phone =~ s/^\s+//;
      $phone =~ s/\s+$//;

      # skip a blank line
      if ( $phone eq '' ) {
        next;
      }
      $lab = $mlf{'mon'};

      if ( grep( $_ eq $phone, keys %mdcp ) <= 0 ) {
        if ( $paral == 1 ) { # qsub /slurm
          $im = 0 if(++$im > $#mname);
          $bs_phone = "$htslogdir/$phone.sh";
          open BS,">$bs_phone";
          print BS "#!/bin/bash\n";
          print BS "echo \"run on : `uname -a`\"\necho \"=============== $phone ================\"\n";
          $cmd = "$HInit -H $initmmf{'cmp'} -M $hinit{'cmp'} -I $lab -l $phone -o $phone $prtfile{'cmp'}";
          print BS "$cmd\n";
          $cmd = "$HRest -H $initmmf{'cmp'} -M $hrest{'cmp'} -I $lab -l $phone -g $hrest{'dur'}/$phone $hinit{'cmp'}/$phone";
          print BS "$cmd\n";
          print BS "echo done\n";
          close BS;
          if($slurm_qsub){
            $str = `sbatch -p cpuq/sjtu -J $phone -D ./ -o $htslogdir/$phone.log -e $htslogdir/$phone.log $bs_phone`;
            if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
              push @jobs, $1;
              print $str;
            }else{
              die $str;
            }
          }else{
            $str = `qsub -l h=$mname[$im] -cwd -o $htslogdir/$phone.log -N $phone -j y -S /bin/bash $bs_phone`;
            chomp $str; print "$str\n";
            @arr = split /\s+/, $str;
            push @jobs, $arr[2];
          }
        }
        elsif ( $paral == 2 ) { # multi-thread
          push @jobs, threads->create(\&shell, "$HInit -H $initmmf{'cmp'} -M $hinit{'cmp'} -I $lab -l $phone -o $phone $prtfile{'cmp'}");
          push @jobs, threads->create(\&shell, "$HRest -H $initmmf{'cmp'} -M $hrest{'cmp'} -I $lab -l $phone -g $hrest{'dur'}/$phone $hinit{'cmp'}/$phone");
        } 
        else { # sequence
          print "=============== $phone ================\n";
          shell("$HInit -H $initmmf{'cmp'} -M $hinit{'cmp'} -I $lab -l $phone -o $phone $prtfile{'cmp'}");
          shell("$HRest -H $initmmf{'cmp'} -M $hrest{'cmp'} -I $lab -l $phone -g $hrest{'dur'}/$phone $hinit{'cmp'}/$phone");
        }
      }
    }
    close(LIST);
    # wait for jobs
    if ( $paral == 1 ) {
      wait_jobs(@jobs);
      print "jobs done at : ", `date`, "\n";
    }
    elsif ( $paral == 2 ) { 
      foreach $th (@jobs){
        $th->join();
      }
      print "thread done at : ", `date`, "\n";
    }


    open( LIST, $lst{'mon'} ) || die "Cannot open $!";
    while ( $phone = <LIST> ) {

      # trimming leading and following whitespace characters
      $phone =~ s/^\s+//;
      $phone =~ s/\s+$//;

      # skip a blank line
      if ( $phone eq '' ) {
        next;
      }

      if ( grep( $_ eq $phone, keys %mdcp ) > 0 ) {
        print "=============== $phone ================\n";
        print "use $mdcp{$phone} instead of $phone\n";
        foreach $set (@SET) {
          open( SRC, "$hrest{$set}/$mdcp{$phone}" ) || die "Cannot open $!";
          open( TGT, ">$hrest{$set}/$phone" )       || die "Cannot open $!";
          while (<SRC>) {
            s/~h \"$mdcp{$phone}\"/~h \"$phone\"/;
            print TGT;
          }
          close(TGT);
          close(SRC);
        }
      }
    }
    close(LIST);
  }
}

# HHEd (making a monophone mmf)
if ($MMMMF && !$align_first) {
  print_time("making a monophone mmf");

  foreach $set (@SET) {
    open( EDFILE, ">$lvf{$set}" ) || die "Cannot open $!";

    # load variance floor macro
    print EDFILE "// load variance flooring macro\n";
    print EDFILE "FV \"$vfloors{$set}\"\n";

    # tie stream weight macro
    foreach $type ( @{ $ref{$set} } ) {
      if ( $strw{$type} != 1.0 ) {
        print EDFILE "// tie stream weights\n";
        printf EDFILE "TI SW_all {*.state[%d-%d].weights}\n", 2, $nState + 1;
        last;
      }
    }

    close(EDFILE);

    shell("$HHEd{'trn'} -d $hrest{$set} -w $monommf{$set} $lvf{$set} $lst{'mon'}");
    shell("gzip -c $monommf{$set} > $monommf{$set}.nonembedded.gz") if($gzip);
  }
}

# HERest (embedded reestimation (monophone))
if ($ERST0 && !$align_first) {
  print_time("embedded reestimation (monophone)");

  if ($daem) {
    for ( my $i = 1 ; $i <= $daem_nIte ; $i++ ) {
      for ( my $j = 1 ; $j <= $nIte ; $j++ ) {
        # embedded reestimation
        $k = $j + ( $i - 1 ) * $nIte;
        my $k_cnt = $k;
        print("\n\nIteration $k of Embedded Re-estimation\n");
        $k = ( $i / $daem_nIte )**$daem_alpha;

        #added by zhx66 to parallize the 'HERest'
        @jobs = ();
        if( $paral == 1){
          print("\n start of embedded reestimation ( monophone ) test\n");
          @scpfn = &split_scp($scp{'trn'}, $taskno4HERest, "mono_reestimation_$k_cnt");
          $im = 0;
          foreach $file(@scpfn){
            $im += 1;
            $bsfn = "$file.sh";
            open BS, ">$bsfn";
            print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";
            #shell("$HERest{'mon_modi'} -p 0 -k $k -H $monommf{'cmp'} -N $monommf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'mon'} $lst{'mon'} $data_str");
            print BS "$HERest{'mon_modi'} -S $file -p $im -k $k -H $monommf{'cmp'} -N $monommf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'mon'} $lst{'mon'}\n";
            print BS "echo done\n";
            close BS;
            if($slurm_qsub){
              my $par = &simple_get_partition($im);
              $str = `sbatch --mem=10G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
              if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
                push @jobs, $1;
                print $str;
              }else{
                die $str;
              }
            }
          }
        }
        # wait fore jobs
        if ( $paral == 1){&wait_jobs(@jobs);}
        # combine model
        if( $paral == 1){
          my $data_str;
          for(my $it = 1; $it <= $taskno4HERest; $it+=1){
            $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
            $data_str .= " $model{'cmp'}/HER$it.dur.acc";
          }
          shell("$HERest{'mon_modi'} -p 0 -k $k -H $monommf{'cmp'} -N $monommf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'mon'} $lst{'mon'} $data_str");
          shell("rm $data_str");
          print_time("\n end of model Estimation\n");
        }
        else{ # no paral 
          shell("$HERest{'mon'} -k $k -H $monommf{'cmp'} -N $monommf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'mon'} $lst{'mon'}");
        }
      } # end of j
    } # end of i
  } # end of if deam
  else { # no daem
    for ( $i = 1 ; $i <= $nIte ; $i++ ) {
      # embedded reestimation
      print("\n\nIteration $i of Embedded Re-estimation\n");
      shell("$HERest{'mon'} -H $monommf{'cmp'} -N $monommf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'mon'} $lst{'mon'}");
    }
  }

  # compress reestimated model
  foreach $set (@SET) {
    shell("gzip -c $monommf{$set} > ${monommf{$set}}.embedded.gz") if($gzip);
  }
}
# re-align (用monophone mmf切分mono.mlf，$REALGN=迭代次数)
# 这里是用viterbi算法寻找最优状态序列
# 而对其理解为使用上面的方法将每个cmp中的音素和文本相对应起来
if ($REALGN > 0 && $IN_RE && $MMMMF && $ERST0) {
  print_time("Iteration $REALGN of re-align using monophone mmf");

  mkdir $labfaldir, 0755;
  # cut scp file
  @scpfn = &split_scp($scp{'trn'}, $taskno);

  # re-align
  @jobs = (); $im = -1;
  foreach $file (@scpfn){
    if ( $paral == 1 ) {
      $im = 0 if ( ++$im > $#mname );
      $bsfn = "$file.sh";
      open BS, ">$bsfn";
      print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";
      print BS "$HSMMAlign -S $file -H $monommf{'cmp'} -N $monommf{'dur'} -m $labfaldir $lst{'mon'} $lst{'mon'}\n";
      print BS "echo done\n";
      close BS;
      if($slurm_qsub){
        $str = `sbatch -p cpuq/sjtu -D ./ -o $file.log -e $file.log $bsfn`;
        if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
          push @jobs, $1;
          print $str;
        }else{
          die $str;
        }
      }else{
        $str = `qsub -l h=$mname[$im] -cwd -o $file.log -j y -S /bin/bash $bsfn`;
        chomp $str; print "$str\n";
        @arr = split /\s+/, $str;
        push @jobs, $arr[2];
      }
    }
    elsif ( $paral == 2 ) { 
      push @jobs, threads->create(\&shell, "$HSMMAlign -S $file -H $monommf{'cmp'} -N $monommf{'dur'} -m $labfaldir $lst{'mon'} $lst{'mon'} > $file.log");
    }
    else {
      shell("$HSMMAlign -S $scp{'trn'} -H $monommf{'cmp'} -N $monommf{'dur'} -m $labfaldir $lst{'mon'} $lst{'mon'} > $file.log");
    }
  }

  # wait for jobs
  if ( $paral == 1 ) {
    &wait_jobs(@jobs);
  }
  elsif ( $paral == 2 ) { 
    foreach $th ( @jobs ) {
      $th->join();
    }
  } 

  # combine .lab
  $mlf = load_mlf($mlf{'mon'});
  opendir DIR, $labfaldir;
  @arr = readdir DIR;
  closedir DIR;
  foreach $fn ( @arr ){
    next if($fn eq "." || $fn eq "..");
    add_labfile($mlf, "$labfaldir/$fn");
  }
  save_mlf($mlf, $mlf{'mon'});
  $align_first = 0;

  # goto Re_Align;
  if ( $REALGN > 0 ) {
    $REALGN --;
    if ( $REALGN == 0 ) { # clean up
      foreach $file (@scpfn){
        unlink $file;
        unlink "$file.sh";
        unlink "$file.log";
      }
    }
    $daem = 0;
    goto Re_Align;
  }
}
# HHEd (copying monophone mmf to fullcontext one)
# 用单音节模型初始化full模型
if ($MN2FL) {
  print_time("copying monophone mmf to fullcontext one");

  foreach $set (@SET) {
    open( EDFILE, ">$m2f{$set}" ) || die "Cannot open $!";
    open( LIST,   "$lst{'mon'}" ) || die "Cannot open $!";

    print EDFILE "// copy monophone models to fullcontext ones\n";
    print EDFILE "CL \"$lst{'ful'}\"\n\n";    # CLone monophone to fullcontext

    print EDFILE "// tie state transition probability\n";
    while ( $phone = <LIST> ) {

      # trimming leading and following whitespace characters
      $phone =~ s/^\s+//;
      $phone =~ s/\s+$//;

      # skip a blank line
      if ( $phone eq '' ) {
        next;
      }
      print EDFILE "TI T_${phone} {*-${phone}+*.transP}\n";    # TIe transition prob
    }
    close(LIST);
    close(EDFILE);

    shell("$HHEd{'trn'} -H $monommf{$set} -w $fullmmf{$set} $m2f{$set} $lst{'mon'}");
    shell("gzip -c $fullmmf{$set} > $fullmmf{$set}.nonembedded.gz") if($gzip);
  }
}

# HERest (embedded reestimation (fullcontext))
if ($ERST1) {
  print_time("embedded reestimation (fullcontext)");

  $opt = "-C $cfg{'nvf'} -s $stats{'cmp'} -w 0.0";

  # embedded reestimation
  #added by zhx66 to parallize the 'HERest'
  @jobs = ();
  if( $paral == 1){
    print("\n start of embedded reestimation ( fullcontext) test\n");
    @scpfn = &split_scp($scp{'trn'}, $taskno4full, "full_reestimate");
    $im = 0;
    foreach $file(@scpfn){
      $im += 1;
      $bsfn = "$file.sh";
      open BS, ">$bsfn";
      print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";

      print BS "$HERest{'ful_modi'} -S $file -p $im -H $fullmmf{'cmp'} -N $fullmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}\n";
      print BS "echo done\n";
      close BS;

      if($slurm_qsub){
        my $par = &simple_get_partition($im);
        $str = `sbatch --mem=$full_mem -p $par -D ./ -o $file.log -e $file.log $bsfn`;
        if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
          push @jobs, $1;
          print $str;
        }else{
          die $str;
        }
      }
    }
  }

  # wait fore jobs
  if ( $paral == 1){
    &wait_jobs(@jobs);
  }

  # combine model
  if( $paral == 1){
    my $data_str;
    for(my $it = 1; $it <= $taskno4full; $it+=1){
      $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
      $data_str .= " $model{'cmp'}/HER$it.dur.acc";
    }
    shell("$HERest{'ful_modi'} -p 0 -H $fullmmf{'cmp'} -N $fullmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'} $data_str");
    shell("rm $data_str");
    print_time("\n end of model Estimation\n");
  }
  else{
    print("\n\nEmbedded Re-estimation\n");
    shell("$HERest{'ful'} -H $fullmmf{'cmp'} -N $fullmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}");
  }

  # compress reestimated model
  foreach $set (@SET) {
    shell("gzip -c $fullmmf{$set} > ${fullmmf{$set}}.embedded.gz") if($gzip);
  }
}

# HHEd (tree-based context clustering)
if ($CXCL1) {
  print_time("tree-based context clustering");

  foreach $set (@SET) {
    foreach $type ( @{ $ref{$set} } ) {
      if ( defined $LOCK_QS && $LOCK_QS ne "" && $type ne "bap" ) {
        $aaa = 1.5;
        $aaa = 2.0 if($type eq "lf0");
        $myopt{$type} = "-l $LOCK_QS $mdlf{$type} $aaa " if ( $thr{$type} eq '000' );
      }
      else {
        $myopt{$type} = "";
      }
    }
  }

  # convert cmp stats to duration ones
  convstats();

  # tree-based clustering
  $nstate{'cmp'} = $nState;
  $nstate{'dur'} = 1;
  @jobs = (); $im = -1;
  if ( $paral == 1 ) {
    foreach $set (@SET) {
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        shell("cp $fullmmf{$set} $clusmmf{$set}.s$i");

        $bsfn = "$htslogdir/cxc1_${set}.s${i}.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\n\necho \"run on : `uname -a`\"\ndate\n";

        foreach $type ( @{ $ref{$set} } ) {
          if ( $strw{$type} > 0.0 ) {
            make_edfile_state($type,$paral);
            print BS "$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $clusmmf{$set}.s$i $mdl{$type} -w $clusmmf{$set}.s$i $cxc{$type}.s$i $lst{'ful'}\ndate\n";
          }
        }

        print BS "echo done\n";
        close BS;
        $im = 0 if ( ++$im > $#mname );
        if($slurm_qsub){
          $str = `sbatch -p limitcpu --mem=$maxmem -D ./ -o $bsfn.log -e $bsfn.log -J ${spkr}_cxc1_${set}_s${i} $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }else{
          $str = `qsub -l h=$mname[$im] -cwd -o $bsfn.log -j y -N ${spkr}_cxc1_${set}_s${i} -S /bin/bash $bsfn`;
          chomp $str; print "$str\n";
          @arr = split /\s+/, $str;
          push @jobs, $arr[2];
        }
      }
    }
  }
  elsif ( $paral == 2 ) {
    foreach $set (@SET) {
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        shell("cp $fullmmf{$set} $clusmmf{$set}.s$i");

        $cmd = "";
        foreach $type ( @{ $ref{$set} } ) {
          if ( $strw{$type} > 0.0 ) {
            make_edfile_state($type,$paral);
            $cmd .= "$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $clusmmf{$set}.s$i $mdl{$type} -w $clusmmf{$set}.s$i $cxc{$type}.s$i $lst{'ful'};";
          }
        }

        push @jobs, threads->create(\&shell, $cmd);
      }
    }
  }
  else { 
    foreach $set (@SET) {
      shell("cp $fullmmf{$set} $clusmmf{$set}");

      $footer = "";
      foreach $type ( @{ $ref{$set} } ) {
        if ( $strw{$type} > 0.0 ) {
          make_edfile_state($type,$paral);
          shell("$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $clusmmf{$set} $mdl{$type} -w $clusmmf{$set} $cxc{$type} $lst{'ful'}");
          $footer .= "_$type";
          shell("gzip -c $clusmmf{$set} > $clusmmf{$set}$footer.gz") if($gzip);
        }
      }
    }
  }

  # wait for jobs
  if ( $paral == 1 ) { 
    wait_jobs(@jobs);
  }
  elsif ( $paral == 2 ) { 
    foreach $th ( @jobs ) {
      $th->join();
    }
  }
  # combine mmf file
  @del_files = ();
  if ( $paral == 1 || $paral == 2 ) {
    foreach $set (@SET) {
      if ( $set eq 'dur' ) { 
        rename "$clusmmf{$set}.s2", "$clusmmf{$set}";
        next;
      }
      $cmd = "$HHEd{'trn'}";
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        $cmd .= " -H $clusmmf{$set}.s$i:s$i";
        push @del_files, "$clusmmf{$set}.s$i";
      }
      $cmd .= " -w $clusmmf{$set} /dev/null $lst{'ful'}";
      shell($cmd);
    }
  }
  # clean
  foreach ( @del_files ) {
    unlink $_;
  }
}

# HERest (embedded reestimation (clustered))
if ($ERST2) {
  print_time("embedded reestimation (clustered)");

  @jobs = ();
  for (my $i = 1 ; $i <= $nIte ; $i++ ) {
    print_time("\n start $i-th embedded reestimation (clustered) \n");
    #added by zhx66 to parallize the 'HERest'
    if( $paral == 1){
      print("\n start of herest test\n");
      @scpfn = &split_scp($scp{'trn'}, $taskno4HERest, "clustered_reestimate_$i");
      $im = 0;
      foreach $file(@scpfn){
        $im += 1;
        $bsfn = "$file.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";

        print BS "$HERest{'ful_modi'} -p $im -S $file -H $clusmmf{'cmp'} -N $clusmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'}\n";
        print BS "echo done\n";
        close BS;

        if($slurm_qsub){
          my $par = &simple_get_partition($im);
          $str = `sbatch --mem=10G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }
      }
    }

    # wait fore jobs
    if ( $paral == 1){
      &wait_jobs(@jobs);
    }

    # combine model
    if( $paral == 1){
      my $data_str;
      for(my $it = 1; $it <= $taskno4HERest; $it+=1){
        $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
        $data_str .= " $model{'cmp'}/HER$it.dur.acc";
      }
      shell("$HERest{'ful_modi'} -p 0 -H $clusmmf{'cmp'} -N $clusmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'} $data_str");
      shell("rm $data_str");
      print_time("\n end of model Estimation\n");
    }

    else{
      print("\n\nIteration $i of Embedded Re-estimation\n");
      shell("$HERest{'ful'} -H $clusmmf{'cmp'} -N $clusmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'}");
    }
  }

  # compress reestimated mmfs
  foreach $set (@SET) {
    shell("gzip -c $clusmmf{$set} > $clusmmf{$set}.embedded.gz") if($gzip);
  }
}

# HHEd (untying the parameter sharing structure)
if ($UNTIE) {
  print_time("untying the parameter sharing structure");

  foreach $set (@SET) {
    make_edfile_untie($set);
    shell("$HHEd{'trn'} -H $clusmmf{$set} -w $untymmf{$set} $unt{$set} $lst{'ful'}");
  }
}

# fix variables
foreach $set (@SET) {
  $stats{$set} .= ".untied";
  foreach $type ( @{ $ref{$set} } ) {
    $tre{$type} .= ".untied";
    $cxc{$type} .= ".untied";
  }
}

# HERest (embedded reestimation (untied))
if ($ERST3) {
  print_time("embedded reestimation (untied)");

  $opt = "-C $cfg{'nvf'} -s $stats{'cmp'} -w 0.0";
  if( $paral == 1){
    print("\n start of herest test\n");
    @scpfn = &split_scp($scp{'trn'}, $taskno4HERest, "untied_reestimate");
    $im = 0;
    foreach $file(@scpfn){
      $im += 1;
      $bsfn = "$file.sh";
      open BS, ">$bsfn";
      print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";

      print BS "$HERest{'ful_modi'} -p $im -S $file -H $untymmf{'cmp'} -N $untymmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}\n";
      print BS "echo done\n";
      close BS;

      if($slurm_qsub){
        my $par = &simple_get_partition($im);
        $str = `sbatch --mem=20G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
        if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
          push @jobs, $1;
          print $str;
        }else{
          die $str;
        }
      }
    }
  }

  # wait fore jobs
  if ( $paral == 1){
    &wait_jobs(@jobs);
  }

  # combine model
  if( $paral == 1){
    my $data_str;
    for(my $it = 1; $it <= $taskno4HERest; $it+=1){
      $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
      $data_str .= " $model{'cmp'}/HER$it.dur.acc";
    }
    shell("$HERest{'ful_modi'} -p 0 -H $untymmf{'cmp'} -N $untymmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'} $data_str");
    shell("rm $data_str");
    print_time("\n end of model Estimation\n");
  }
  else{
    print("\n\nEmbedded Re-estimation for untied mmfs\n");
    shell("$HERest{'ful'} -H $untymmf{'cmp'} -N $untymmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}");
  }
}

# HHEd (tree-based context clustering)
if ($CXCL2) {
  print_time("tree-based context clustering");

  foreach $set (@SET) {
    foreach $type ( @{ $ref{$set} } ) {
      if ( defined $LOCK_QS && $LOCK_QS ne "" && $type ne "bap" ) {
        $aaa = 1.5;
        $aaa = 2.0 if($type eq "lf0");
        $myopt{$type} = "-l $LOCK_QS $mdlf{$type} $aaa " if ( $thr{$type} eq '000' );
      }
      else {
        $myopt{$type} = "";
      }
    }
  }

  # convert cmp stats to duration ones
  convstats();

  # tree-based clustering
  $nstate{'cmp'} = $nState;
  $nstate{'dur'} = 1;
  @jobs = (); $im = -1;
  if ( $paral == 1 ) {
    foreach $set (@SET) {
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        shell("cp $untymmf{$set} $reclmmf{$set}.s$i");

        $bsfn = "$htslogdir/cxc2_${set}.s${i}.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\n\necho \"run on : `uname -a`\"\ndate\n";

        foreach $type ( @{ $ref{$set} } ) {
          make_edfile_state($type,$paral);
          print BS "$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $reclmmf{$set}.s$i $mdl{$type} -w $reclmmf{$set}.s$i $cxc{$type}.s$i $lst{'ful'}\ndate\n";
        }

        print BS "echo done\n";
        close BS;
        $im = 0 if ( ++$im > $#mname );
        if($slurm_qsub){
          $str = `sbatch -p limitcpu --mem=$maxmem -D ./ -o $bsfn.log -e $bsfn.log -J ${spkr}_cxc2_${set}_s${i} $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }else{
          $str = `qsub -l h=$mname[$im] -cwd -o $bsfn.log -j y -N ${spkr}_cxc2_${set}_s${i} -S /bin/bash $bsfn`;
          chomp $str; print "$str\n";
          @arr = split /\s+/, $str;
          push @jobs, $arr[2];
        }
      }
    }
  }
  elsif ( $paral == 2 ) {
    foreach $set (@SET) {
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        shell("cp $untymmf{$set} $reclmmf{$set}.s$i");

        $cmd = "";
        foreach $type ( @{ $ref{$set} } ) {
          make_edfile_state($type,$paral);
          $cmd .= "$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $reclmmf{$set}.s$i $mdl{$type} -w $reclmmf{$set}.s$i $cxc{$type}.s$i $lst{'ful'};";
        }

        push @jobs, threads->create(\&shell, $cmd);
      }
    }
  }
  else { 
    foreach $set (@SET) {
      shell("cp $untymmf{$set} $reclmmf{$set}");

      $footer = "";
      foreach $type ( @{ $ref{$set} } ) {
        make_edfile_state($type,$paral);
        shell("$HHEd{'trn'} $myopt{$type} -C $cfg{$type} -H $reclmmf{$set} $mdl{$type} -w $reclmmf{$set} $cxc{$type} $lst{'ful'}");

        $footer .= "_$type";
        shell("gzip -c $reclmmf{$set} > $reclmmf{$set}$footer.gz") if($gzip);
      }
      shell("gzip -c $reclmmf{$set} > $reclmmf{$set}.nonembedded.gz") if($gzip);
    }
  }

  # wait for jobs
  if ( $paral == 1 ) {
    wait_jobs(@jobs);
  }
  elsif ( $paral == 2 ) {
    foreach $th ( @jobs ) {
      $th->join();
    }
  }
  # combine mmf files
  @del_files = ();
  if ( $paral == 1 || $paral == 2 ) {
    foreach $set (@SET) {
      if ( $set eq 'dur' ) {
        rename "$reclmmf{$set}.s2", "$reclmmf{$set}";
        next;
      }
      $cmd = "$HHEd{'trn'}";
      for ( $i = 2 ; $i <= $nstate{ $set } + 1 ; $i++ ) {
        $cmd .= " -H $reclmmf{$set}.s$i:s$i";
        push @del_files, "$reclmmf{$set}.s$i";
      }
      $cmd .= " -w $reclmmf{$set} /dev/null $lst{'ful'}";
      shell($cmd);
    }
  }
  # clean
  foreach ( @del_files ) {
    unlink $_;
  }
}

# HERest (embedded reestimation (re-clustered))
if ($ERST4) {
  print_time("embedded reestimation (re-clustered)");
  @jobs = ();
  for (my $i = 1 ; $i <= $nIte ; $i++ ) {
    print_time("\n start $i-th embedded reestimation (re-clustered) \n");
    #added by zhx66 to parallize the 'HERest'
    if( $paral == 1){
      print("\n start of herest test\n");
      @scpfn = &split_scp($scp{'trn'}, $taskno4HERest, "re_clustered_$i");
      $im = 0;
      foreach $file(@scpfn){
        $im += 1;
        $bsfn = "$file.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";

        print BS "$HERest{'ful_modi'} -p $im -S $file -H $reclmmf{'cmp'} -N $reclmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'}\n";
        print BS "echo done\n";
        close BS;

        if($slurm_qsub){
          my $par = &simple_get_partition($im);
          $str = `sbatch --mem=10G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }
      }
    }

    # wait fore jobs
    if ( $paral == 1){
      &wait_jobs(@jobs);
    }

    # combine model
    if( $paral == 1){
      my $data_str;
      for(my $it = 1; $it <= $taskno4HERest; $it+=1){
        $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
        $data_str .= " $model{'cmp'}/HER$it.dur.acc";
      }
      shell("$HERest{'ful_modi'} -p 0 -H $reclmmf{'cmp'} -N $reclmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'} $data_str");
      shell("rm $data_str");
      print_time("\n end of model Estimation\n");
    }

    else{
      print("\n\nIteration $i of Embedded Re-estimation\n");
      shell("$HERest{'ful'} -H $reclmmf{'cmp'} -N $reclmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $lst{'ful'} $lst{'ful'}");
    }
  }


  # compress reestimated mmfs
  foreach $set (@SET) {
    shell("gzip -c $reclmmf{$set} > $reclmmf{$set}.embedded.gz") if($gzip);
  }
}

# HSMMAlign (forced alignment)
if ($FALGN) {
  print_time("forced alignment");

  if ( ( $useGV && $nosilgv && @slnt > 0 ) || ($useMSPF) ) {

    # make directory
    mkdir "$gvfaldir", 0755;

    # cut scp file
    @scpfn = &split_scp($scp{'trn'}, $taskno4HSMM);

    # re-align
    @jobs = (); $im = -1;
    foreach $file (@scpfn){
      if ( $paral == 1 ) {
        $im = 0 if ( ++$im > $#mname );
        $bsfn = "$file.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";
        print BS "$HSMMAlign -S $file -H $monommf{'cmp'} -N $monommf{'dur'} -m $gvfaldir $lst{'mon'} $lst{'mon'}\n";
        print BS "echo done\n";
        close BS;
        if($slurm_qsub){
          my $par = &simple_get_partition($im);
          $str = `sbatch -p $par -D ./ -o $file.log -e $file.log $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }else{
          $str = `qsub -l h=$mname[$im] -cwd -o $file.log -j y -S /bin/bash $bsfn`;
          chomp $str; print "$str\n";
          @arr = split /\s+/, $str;
          push @jobs, $arr[2];
        }
      }
      elsif ( $paral == 2 ) {
        push @jobs, threads->create(\&shell, "$HSMMAlign -S $file -H $monommf{'cmp'} -N $monommf{'dur'} -m $gvfaldir $lst{'mon'} $lst{'mon'} > $file.log");
      }
      else {
        shell("$HSMMAlign -S $scp{'trn'} -H $monommf{'cmp'} -N $monommf{'dur'} -m $gvfaldir $lst{'mon'} $lst{'mon'} > $file.log");
      }
    }

    # wait for jobs
    if ( $paral == 1 ) {
      &wait_jobs(@jobs);
    }
    elsif ( $paral == 2 ) {
      foreach $th ( @jobs ) {
        $th->join();
      }
    }

    # combine .lab
    $mlf = load_mlf($mlf{'mon'});
    opendir DIR, $gvfaldir;
    @arr = readdir DIR;
    closedir DIR;
    foreach $fn ( @arr ){
      next if($fn eq "." || $fn eq "..");
      add_labfile($mlf, "$gvfaldir/$fn");
    }
    save_mlf($mlf, "$gvdir/mono.mlf");
  }
}

# making global variance
# 在model之间都要算一下gv？
if ($MCDGV) {
  print_time("making global variance");

  if ($useGV) {

    # make directories
    mkdir "$gvdatdir", 0755;
    mkdir "$gvlabdir", 0755;

    # make proto
    make_proto_gv();

    # make training data, labels, scp, list, and mlf
    make_data_gv();

    # make average model
    shell("$HCompV{'gv'} -o $avermmf{'gv'} -M $gvdir $prtfile{'gv'}");

    if ($cdgv) {

      # make full context depdent model
      copy_aver2full_gv();
      shell("$HERest{'gv'} -C $cfg{'nvf'} -s $gvdir/gv.stats -w 0.0 -H $fullmmf{'gv'} -M $gvdir $gvdir/gv.list");

      # context-clustering
      my $s = 1;
      shell("cp $fullmmf{'gv'} $clusmmf{'gv'}");
      foreach $type (@cmp) {
        make_edfile_state_gv( $type, $s );
        shell("$HHEd{'trn'} -H $clusmmf{'gv'} $gvmdl{$type} -w $clusmmf{'gv'} $gvcxc{$type} $gvdir/gv.list");
        $s++;
      }

      # re-estimation
      shell("$HERest{'gv'} -H $clusmmf{'gv'} -M $gvdir $gvdir/gv.list");
    }
    else {
      my $s = 1;
      foreach $type (@cmp) {
        make_edfile_state_gv( $type, $s );
        $s++;
      }
      copy_aver2clus_gv();
    }
  }
}

# HHEd (making unseen models (GV))
if ($MKUNG) {
  print_time("making unseen models (GV)");

  if ($useGV) {
    if ($cdgv) {
      make_edfile_mkunseen_gv();
      shell("$HHEd{'trn'} -H $clusmmf{'gv'} -w $clsammf{'gv'} $mku{'gv'} $gvdir/gv.list");
    }
    else {
      copy_clus2clsa_gv();
    }
  }
}

# HHEd (making unseen models (speaker independent))
if ($MKUN1) {
  print_time("making unseen models (speaker independent)");

  foreach $set (@SET) {
    make_edfile_mkunseen($set);
    shell("$HHEd{'trn'} -H $reclmmf{$set} -w $rclammf{$set} $mku{$set} $lst{'ful'}");
  }
}

# HMGenS (generating speech parameter sequences (speaker independent))
if ($PGEN1) {
  print_time("generating speech parameter sequences (speaker independent)");

  $mix = 'SI';
  $dir = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";
  mkdir "${prjdir}/gen/qst${qnum}/ver${ver}/$mix", 0755;
  mkdir $dir, 0755;

  # generate parameter
  shell("$HMGenS -c $pgtype -H $rclammf{'cmp'} -N $rclammf{'dur'} -M $dir $tiedlst{'cmp'} $tiedlst{'dur'}");
}

# SPTK (synthesizing waveforms (speaker independent))
if ($WGEN1) {
  print_time("synthesizing waveforms (speaker independent)");

  $mix = 'SI';
  $dir = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  gen_wave("$dir");
}

# HHEd (building regression-class trees for adaptation)
if ($REGTR) {
  print_time("building regression-class trees for adaptation");

  foreach $set (@SET) {
    foreach $type ( 'reg', 'dec' ) {    # reg -> regression tree (k-means),  dec -> decision tree
      make_edfile_regtree( $type, $set );
      shell("$HHEd{'trn'} -C $cfg{'dec'}{$set} -H $reclmmf{$set} -M $regtree{$set} $red{$set}{$type} $lst{'ful'}");
    }
  }
}

# HERest (speaker adaptation (speaker independent))
if ($ADPT1) {
  print_time("speaker adaptation (speaker independent)");

  $type = $tknd{'adp'};
  $mllr = $tran;

  for ( $i = 1 ; $i <= $nAdapt ; $i++ ) {
    print("\n\nIteration $i of adaptation transform reestimation\n");

    # Reestimate transform
    $mix = "SI+${type}_${mllr}${i}";
    $opt = "-C $cfg{'adp'} ";
    $opt .= "-K $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
    $opt .= "-Z $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";

    if ( $i > 1 ) {
      $mix2 = "SI+${type}_${mllr}" . ( ${i} - 1 );
      $opt .= "-J $xforms{'cmp'} ${mix2} -Y $xforms{'dur'} ${mix2} -a -b ";
    }

    shell("$HERest{'adp'} -H $rclammf{'cmp'} -N $rclammf{'dur'} $opt $tiedlst{'cmp'} $tiedlst{'dur'}");
  }

  if ($addMAP) {
    print("\n\nadditional MAP estimation\n");

    $opt = "-C $cfg{'map'} ";

    if ( $nAdapt > 0 ) {
      $mix = "SI+${type}_${mllr}${nAdapt}";
      $opt .= "-H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} -J $xforms{'cmp'} ${mix} -E $xforms{'cmp'} ${mix} -a ";
      $opt .= "-N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} -Y $xforms{'dur'} ${mix} -W $xforms{'dur'} ${mix} -b ";
    }

    shell("$HERest{'map'} -H $rclammf{'cmp'} -N $rclammf{'dur'} -M $mapmmf{'cmp'} -R $mapmmf{'dur'} $opt $tiedlst{'cmp'} $tiedlst{'dur'}");
  }
}

if ($addMAP) {
  for $set (@SET) {
    $rclammf{$set} = "$mapmmf{$set}/re_clustered_all.mmf";
  }
}

# HMGenS (generating speech parameter sequences (speaker adapted))
if ($PGEN2) {
  print_time("generating speech parameter sequences (speaker adapted)");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SI+${type}_${mllr}${nAdapt}";
  $dir  = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  mkdir "${prjdir}/gen/qst${qnum}/ver${ver}/$mix", 0755;
  mkdir $dir, 0755;

  $opt = "-a -J $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
  $opt .= "-b -Y $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";

  # generate parameter
  shell("$HMGenS -c $pgtype -H $rclammf{'cmp'} -N $rclammf{'dur'} -M $dir ${opt} $tiedlst{'cmp'} $tiedlst{'dur'}");
}

# SPTK (synthesizing waveforms (speaker adapted))
if ($WGEN2) {
  print_time("synthesizing waveforms (speaker adapted)");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SI+${type}_${mllr}${nAdapt}";
  $dir  = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  gen_wave("$dir");
}

# HERest (Speaker adaptive training (SAT))
if ($SPKAT) {
  print_time("Speaker adaptive training (SAT)");

  for $set (@SET) {
    shell("cp $reclmmf{$set} $spatmmf{$set}");
  }

  $type = $tknd{'sat'};
  $mllr = 'sat';

  for (my $i = 1 ; $i <= $nSAT ; $i++ ) {
    print("\n\nIteration $i of Speaker Adaptive Training\n");

    # Reestimate transform
    $mix = "${type}_${mllr}${i}";
    $opt = "-u ada -C $cfg{'sat'} ";
    $opt .= "-K $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
    $opt .= "-Z $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";
    if ( $i > 1 ) {
      $mix2 = "${type}_${mllr}" . ( ${i} - 1 );
      $opt .= "-J $xforms{'cmp'} ${mix2} -Y $xforms{'dur'} ${mix2} -a -b ";
    }

    print_time("\nEstimating transform for iteration $i\n");
    # shell("$HERest{'ful'} -H $spatmmf{'cmp'} -N $spatmmf{'dur'} $opt $lst{'ful'} $lst{'ful'}");
    if( $paral == 1){
      @jobs = ();
      @scpfn = &my_split_scp($scp{'trn'}, $ntrn_spkr, "sat_xform_$i");
      my $im = 0;
      foreach $file(@scpfn){
        $im += 1;
        $bsfn = "$file.sh";
        open BS, ">$bsfn";
        print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";
        print BS "$HERest{'ful_modi'} -S $file -H $spatmmf{'cmp'} -N $spatmmf{'dur'} $opt $lst{'ful'} $lst{'ful'}\n";
        print BS "echo done\n";
        close BS;

        if($slurm_qsub){
          my $par = &simple_get_partition($im);
          $str = `sbatch --mem=30G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
          if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
            push @jobs, $1;
            print $str;
          }else{
            die $str;
          }
        }
      }
    }
    else{
      shell("$HERest{'ful'} -H $spatmmf{'cmp'} -N $spatmmf{'dur'} $opt $lst{'ful'} $lst{'ful'}");
    }
    # wait fore jobs
    if ( $paral == 1){
      &wait_jobs(@jobs);
    }

    # Reestimate HMM and duration models
    $opt = "-C $cfg{'sat'} ";
    $opt .= "-a -J $xforms{'cmp'} ${mix} -E $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
    $opt .= "-b -Y $xforms{'dur'} ${mix} -W $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";

    for (my $j = 1 ; $j <= $nIte ; $j++ ) {
      print_time("\n $j-th start sat model Estimation \n");
      #added by zhx66 to parallize the 'HERest'
      @jobs = ();
      if( $paral == 1){
        print("\n start of herest test\n");
        @scpfn = &split_scp($scp{'trn'}, $taskno4SAT, "sat_reestimate_$j");
        $im = 0;
        foreach $file(@scpfn){
          $im += 1;
          $bsfn = "$file.sh";
          open BS, ">$bsfn";
          print BS "#!/bin/bash\necho \"run on : `uname -a`\"\n";

          print BS "$HERest{'ful_modi'} -p $im -S $file -H $spatmmf{'cmp'} -N $spatmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}\n";
          #print BS "$HERest{'ful_modi'} -S $file -H $spatmmf{'cmp'} -N $spatmmf{'dur'}  -M $htslogdir -p $im -R $htslogdir $opt $lst{'ful'} $lst{'ful'}\n";
          print BS "echo done\n";
          close BS;

          if($slurm_qsub){
            my $par = &simple_get_partition($im);
            $str = `sbatch --mem=10G -p $par -D ./ -o $file.log -e $file.log $bsfn`;
            if($str =~ /Submitted\s+batch\s+job\s+(\d+)/){
              push @jobs, $1;
              print $str;
            }else{
              die $str;
            }
          }
        }
      }   

      # wait fore jobs
      if ( $paral == 1){
        &wait_jobs(@jobs);
      }

      # combine model
      if( $paral == 1){
        my $data_str;
        for(my $it = 1; $it <= $taskno4SAT; $it+=1){
          $data_str .= " $model{'cmp'}/HER$it.hmm.acc";
          $data_str .= " $model{'cmp'}/HER$it.dur.acc";
        }
        shell("$HERest{'ful_modi'} -p 0 -H $spatmmf{'cmp'} -N $spatmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'} $data_str");
        shell("rm $data_str");
        print_time("\n end of model Estimation\n");
      }
      # no parallel
      else{
        print("\n\nIteration $j of Embedded Re-estimation in SAT\n");
        shell("$HERest{'ful'} -H $spatmmf{'cmp'} -N $spatmmf{'dur'} -M $model{'cmp'} -R $model{'dur'} $opt $lst{'ful'} $lst{'ful'}");
      }
    }

    # compress reestimated mmfs
    for $set (@SET) {
      shell("gzip -c $spatmmf{$set} > $spatmmf{$set}.${i}.embedded.gz");
    }
  }
}

# HHEd (making unseen models (SAT))
if ($MKUN2) {
  print_time("making unseen models (SAT)");

  foreach $set (@SET) {
    make_edfile_mkunseen($set);
    shell("$HHEd{'trn'} -H $spatmmf{$set} -w $satammf{$set} $mku{$set} $lst{'ful'}");
  }
}

# HMGenS (generating speech parameter sequences (SAT))
if ($PGEN3) {
  print_time("generating speech parameter sequences (SAT)");

  $mix = 'SAT';
  $dir = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";
  mkdir "${prjdir}/gen/qst${qnum}/ver${ver}/$mix", 0755;
  mkdir $dir, 0755;

  # generate parameter
  shell("$HMGenS -c $pgtype -H $satammf{'cmp'} -N $satammf{'dur'} -M $dir $tiedlst{'cmp'} $tiedlst{'dur'}");
}

# SPTK (synthesizing waveforms (SAT))
if ($WGEN3) {
  print_time("synthesizing waveforms (SAT)");

  $mix = 'SAT';
  $dir = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  gen_wave("$dir");
}

# HERest (speaker adaptation (SAT))
if ($ADPT2) {
  print_time("speaker adaptation (SAT)");

  $type = $tknd{'adp'};
  $mllr = $tran;

  for ( $i = 1 ; $i <= $nAdapt ; $i++ ) {
    print("\n\nIteration $i of adaptation transform estimation\n");

    # Reestimate transform
    $mix = "SAT+${type}_${mllr}${i}";

    $opt = "-C $cfg{'adp'} ";
    $opt .= "-K $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
    $opt .= "-Z $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";

    if ( $i > 1 ) {
      $mix2 = "SAT+${type}_${mllr}" . ( ${i} - 1 );
      $opt .= "-J $xforms{'cmp'} ${mix2} -Y $xforms{'dur'} ${mix2} -a -b ";
    }
    else {
      $opt .= "-C $cfg{'aln'}";
    }

    shell("$HERest{'adp'} -H $satammf{'cmp'} -N $satammf{'dur'} $opt $tiedlst{'cmp'} $tiedlst{'dur'}");
  }

  if ($addMAP) {
    print("\n\nadditional MAP estimation\n");

    $opt = "-C $cfg{'map'} ";

    if ( $nAdapt > 0 ) {
      $mix = "SAT+${type}_${mllr}${nAdapt}";
      $opt .= "-H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} -J $xforms{'cmp'} ${mix} -E $xforms{'cmp'} ${mix} -a ";
      $opt .= "-N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} -Y $xforms{'dur'} ${mix} -W $xforms{'dur'} ${mix} -b ";
    }

    shell("$HERest{'map'} -H $satammf{'cmp'} -N $satammf{'dur'} -M $mapmmf{'cmp'} -R $mapmmf{'dur'} $opt $tiedlst{'cmp'} $tiedlst{'dur'}");
  }
}

if ($addMAP) {
  for $set (@SET) {
    $satammf{$set} = "$mapmmf{$set}/re_clustered_sat_all.mmf";
  }
}

# HMGenS (generate speech parameter sequences (SAT+adaptation))
if ($PGEN4) {
  print_time("generate speech parameter sequences (SAT+adaptation)");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SAT+${type}_${mllr}${nAdapt}";
  $dir  = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  mkdir "${prjdir}/gen/qst${qnum}/ver${ver}/$mix", 0755;
  mkdir $dir, 0755;

  $opt = "-a -J $xforms{'cmp'} ${mix} -H $rbase{'cmp'}{$type} -H $rtree{'cmp'}{$type} ";
  $opt .= "-b -Y $xforms{'dur'} ${mix} -N $rbase{'dur'}{$type} -N $rtree{'dur'}{$type} ";

  # generate parameters
  shell("$HMGenS -c $pgtype -H $satammf{'cmp'} -N $satammf{'dur'} -M $dir ${opt} $tiedlst{'cmp'} $tiedlst{'dur'}");
}

# SPTK (synthesizing waveforms (SAT+adaptation))
if ($WGEN4) {
  print_time("synthesizing waveforms (SAT+adaptation)");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SAT+${type}_${mllr}${nAdapt}";
  $dir  = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/$pgtype";

  gen_wave("$dir");
}

# HHEd (converting mmfs to the HTS voice format)
if ( $CONVM && !$usestraight ) {
  print_time("converting mmfs to the HTS voice format");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SAT+${type}_${mllr}${nAdapt}";

  # models and trees
  foreach $set (@SET) {
    $spxf = "$xforms{$set}/${spkr}.${mix}";
    $mmfs = "-H $rbase{$set}{$type} -H $rtree{$set}{$type}";
    foreach $type ( @{ $ref{$set} } ) {
      make_edfile_convert( $type, $paral );
      shell("$HHEd{'trn'} -H $satammf{$set} $mmfs $cnv{$type} $tiedlst{$set}");
      shell("mv $trd{$set}/trees.$strb{$type} $trv{$type}");
      shell("mv $model{$set}/pdf.$strb{$type} $pdf{$type}");
    }
  }

  # window coefficients
  foreach $type (@cmp) {
    shell("cp $windir/${type}.win* $voice");
  }

  # gv pdfs
  if ($useGV) {
    my $s = 1;
    foreach $type (@cmp) {    # convert hts_engine format
      make_edfile_convert_gv($type);
      shell("$HHEd{'trn'} -H $clusmmf{'gv'} $gvcnv{$type} $gvdir/gv.list");
      shell("mv $gvdir/trees.$s $gvtrv{$type}");
      shell("mv $gvdir/pdf.$s $gvpdf{$type}");
      $s++;
    }
  }

  # low-pass filter
  make_lpf(); # bc299: cannot find makefilter.pl

  # make HTS voice
  make_htsvoice( "$voice", "${dset}_${spkr}" );

}elsif($CONVM && $usestraight){#added by bz879, 2017-03-24
  print_time("converting mmfs to the hts_engine file format");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SAT+${type}_${mllr}${nAdapt}";
  #models and trees
  foreach $set (@SET) {
    $spxf = "$xforms{$set}/${spkr}.${mix}";
    $mmfs = "-H $rbase{$set}{$type} -H $rtree{$set}{$type}";
    foreach $type ( @{ $ref{$set} } ) {
      make_edfile_convert( $type, $spxf );
      shell("$HHEd{'trn'} -H $rclammf{$set} $mmfs $cnv{$type} $tiedlst{$set}");
      shell("mv $trd{$set}/trees.$strb{$type} $trv{$type}");
      shell("mv $model{$set}/pdf.$strb{$type} $pdf{$type}");
    }
  }
  #windows coefficients
  foreach $type (@cmp) {
    shell("cp $windir/${type}.win* $voice");
  }
  #gv gen
  if ($useGV) {
    my $s = 1;
    foreach $type (@cmp) {    # convert hts_engine format
      make_edfile_convert_gv($type);
      shell("$HHEd{'cnv'} -H $clusmmf{'gv'} $gvcnv{$type} $gvdir/gv.list");
      shell("mv $gvdir/trees.$s $gvtrv{$type}");
      shell("mv $gvdir/pdf.$s $gvpdf{$type}");
      $s++;
    }
    # low-pass filter
    make_lpf();
  } 
}

# hts_engine (synthesizing waveforms using hts_engine)
if ( $ENGIN && !$usestraight ) {
  print_time("synthesizing waveforms using hts_engine");

  $type = $tknd{'adp'};
  $mllr = $tran;
  $mix  = "SAT+${type}_${mllr}${nAdapt}";
  $dir  = "${prjdir}/gen/qst${qnum}/ver${ver}/$mix/hts_engine";
  mkdir ${dir}, 0755;

  # hts_engine command line & options
  $hts_engine = "$ENGINE -m ${voice}/${dset}_${spkr}.htsvoice ";
  if ( !$useGV ) {
    if ( $gm == 0 ) {
      $hts_engine .= "-b " . ( $pf_mcp - 1.0 ) . " ";
    }
    else {
      $hts_engine .= "-b " . $pf_lsp . " ";
    }
  }

  # generate waveform using hts_engine
  open( SCP, "$scp{'gen'}" ) || die "Cannot open $!";
  while (<SCP>) {
    $lab = $_;
    chomp($lab);
    $base = `basename $lab .lab`;
    chomp($base);

    print "Synthesizing a speech waveform from $lab using hts_engine...";
    shell("$hts_engine -or ${dir}/${base}.raw -ow ${dir}/${base}.wav -ot ${dir}/${base}.trace $lab");
    print "done.\n";
  }
  close(SCP);
}

# sub routines ============================
sub shell($) {
  my ($command) = @_;
  my ($exit);

  $exit = system($command);

  if ( $exit / 256 != 0 ) {
    die "Error in $command\n";
  }
}

sub print_time ($) {
  my ($message) = @_;
  my ($ruler);

  $message .= `date`;

  $ruler = '';
  for (my $i = 0 ; $i <= length($message) + 10 ; $i++ ) {
    $ruler .= '=';
  }

  print "\n$ruler\n";
  print "Start @_ at " . `date`;
  print "$ruler\n\n";
}

# sub routine for generating proto-type model
sub make_proto {
  my ( $i, $j, $k, $s );

  # output prototype definition
  # open proto type definition file
  open( PROTO, ">$prtfile{'cmp'}" ) || die "Cannot open $!";

  # output header
  # output vector size & feature type
  print PROTO "~o <VecSize> $vSize{'cmp'}{'total'} <USER> <DIAGC>";

  # output information about multi-space probability distribution (MSD)
  print PROTO "<MSDInfo> $nstream{'cmp'}{'total'} ";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print PROTO " $msdi{$type} ";
    }
  }

  # output information about stream
  print PROTO "<StreamInfo> $nstream{'cmp'}{'total'}";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      printf PROTO " %d", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
    }
  }
  print PROTO "\n";

  # output HMMs
  print PROTO "<BeginHMM>\n";
  printf PROTO "  <NumStates> %d\n", $nState + 2;

  # output HMM states
  for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {

    # output state information
    print PROTO "  <State> $i\n";

    # output stream weight
    print PROTO "  <SWeights> $nstream{'cmp'}{'total'}";
    foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
        print PROTO " $strw{$type}";
      }
    }
    print PROTO "\n";

    # output stream information
    foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
        print PROTO "  <Stream> $s\n";
        if ( $msdi{$type} == 0 ) {    # non-MSD stream
          # output mean vector
          printf PROTO "    <Mean> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
          for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
            print PROTO "      " if ( $k % 10 == 1 );
            print PROTO "0.0 ";
            print PROTO "\n" if ( $k % 10 == 0 );
          }
          print PROTO "\n" if ( $k % 10 != 1 );

          # output covariance matrix (diag)
          printf PROTO "    <Variance> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
          for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
            print PROTO "      " if ( $k % 10 == 1 );
            print PROTO "1.0 ";
            print PROTO "\n" if ( $k % 10 == 0 );
          }
          print PROTO "\n" if ( $k % 10 != 1 );
        }
        else {    # MSD stream
          # output MSD
          print PROTO "  <NumMixes> 2\n";

          # output 1st space (non 0-dimensional space)
          # output space weights
          print PROTO "  <Mixture> 1 0.5000\n";

          # output mean vector
          printf PROTO "    <Mean> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
          for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
            print PROTO "      " if ( $k % 10 == 1 );
            print PROTO "0.0 ";
            print PROTO "\n" if ( $k % 10 == 0 );
          }
          print PROTO "\n" if ( $k % 10 != 1 );

          # output covariance matrix (diag)
          printf PROTO "    <Variance> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
          for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
            print PROTO "      " if ( $k % 10 == 1 );
            print PROTO "1.0 ";
            print PROTO "\n" if ( $k % 10 == 0 );
          }
          print PROTO "\n" if ( $k % 10 != 1 );

          # output 2nd space (0-dimensional space)
          print PROTO "  <Mixture> 2 0.5000\n";
          print PROTO "    <Mean> 0\n";
          print PROTO "    <Variance> 0\n";
        }
      }
    }
  }

  # output state transition matrix
  printf PROTO "  <TransP> %d\n", $nState + 2;
  print PROTO "    ";
  for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
    print PROTO "1.000e+0 " if ( $j == 2 );
    print PROTO "0.000e+0 " if ( $j != 2 );
  }
  print PROTO "\n";
  print PROTO "    ";
  for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
    for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
      print PROTO "6.000e-1 " if ( $i == $j );
      print PROTO "4.000e-1 " if ( $i == $j - 1 );
      print PROTO "0.000e+0 " if ( $i != $j && $i != $j - 1 );
    }
    print PROTO "\n";
    print PROTO "    ";
  }
  for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
    print PROTO "0.000e+0 ";
  }
  print PROTO "\n";

  # output footer
  print PROTO "<EndHMM>\n";

  close(PROTO);
}

sub make_duration_vfloor {
  my ( $dm, $dv ) = @_;
  my ( $i, $j );

  # output variance flooring macro for duration model
  open( VF, ">$vfloors{'dur'}" ) || die "Cannot open $!";
  for ( $i = 1 ; $i <= $nState ; $i++ ) {
    print VF "~v varFloor$i\n";
    print VF "<Variance> 1\n";
    $j = $dv * $vflr{'dur'};
    print VF " $j\n";
  }
  close(VF);

  # output average model for duration model
  open( MMF, ">$avermmf{'dur'}" ) || die "Cannot open $!";
  print MMF "~o\n";
  print MMF "<STREAMINFO> $nState";
  for ( $i = 1 ; $i <= $nState ; $i++ ) {
    print MMF " 1";
  }
  print MMF "\n";
  print MMF "<VECSIZE> ${nState}<NULLD><USER><DIAGC>\n";
  print MMF "~h \"$avermmf{'dur'}\"\n";
  print MMF "<BEGINHMM>\n";
  print MMF "<NUMSTATES> 3\n";
  print MMF "<STATE> 2\n";
  for ( $i = 1 ; $i <= $nState ; $i++ ) {
    print MMF "<STREAM> $i\n";
    print MMF "<MEAN> 1\n";
    print MMF " $dm\n";
    print MMF "<VARIANCE> 1\n";
    print MMF " $dv\n";
  }
  print MMF "<TRANSP> 3\n";
  print MMF " 0.0 1.0 0.0\n";
  print MMF " 0.0 0.0 1.0\n";
  print MMF " 0.0 0.0 0.0\n";
  print MMF "<ENDHMM>\n";
  close(MMF);
}

# sub routine for generating proto-type model for GV
sub make_proto_gv {
  my ( $s, $type, $k );

  open( PROTO, "> $prtfile{'gv'}" ) || die "Cannot open $!";
  $s = 0;
  foreach $type (@cmp) {
    $s += $ordr{$type};
  }
  print PROTO "~o <VecSize> $s <USER> <DIAGC>\n";
  print PROTO "<MSDInfo> $nPdfStreams{'cmp'} ";
  foreach $type (@cmp) {
    print PROTO "0 ";
  }
  print PROTO "\n";
  print PROTO "<StreamInfo> $nPdfStreams{'cmp'} ";
  foreach $type (@cmp) {
    print PROTO "$ordr{$type} ";
  }
  print PROTO "\n";
  print PROTO "<BeginHMM>\n";
  print PROTO "  <NumStates> 3\n";
  print PROTO "  <State> 2\n";
  $s = 1;
  foreach $type (@cmp) {
    print PROTO "  <Stream> $s\n";
    print PROTO "    <Mean> $ordr{$type}\n";
    for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
      print PROTO "      " if ( $k % 10 == 1 );
      print PROTO "0.0 ";
      print PROTO "\n" if ( $k % 10 == 0 );
    }
    print PROTO "\n" if ( $k % 10 != 1 );
    print PROTO "    <Variance> $ordr{$type}\n";
    for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
      print PROTO "      " if ( $k % 10 == 1 );
      print PROTO "1.0 ";
      print PROTO "\n" if ( $k % 10 == 0 );
    }
    print PROTO "\n" if ( $k % 10 != 1 );
    $s++;
  }
  print PROTO "  <TransP> 3\n";
  print PROTO "    0.000e+0 1.000e+0 0.000e+0 \n";
  print PROTO "    0.000e+0 0.000e+0 1.000e+0 \n";
  print PROTO "    0.000e+0 0.000e+0 0.000e+0 \n";
  print PROTO "<EndHMM>\n";
  close(PROTO);
}

# sub routine for making training data, labels, scp, list, and mlf for GV
sub make_data_gv {
  my ( $type, $cmp, $base, $str, @arr, $start, $end, $find, $i, $j );

  shell("rm -f $scp{'gv'}");
  shell("touch $scp{'gv'}");
  open( SCP, $scp{'trn'} ) || die "Cannot open $!";
  if ($cdgv) {
    open( LST, "> $gvdir/tmp.list" );
  }
  while (<SCP>) {
    $cmp = $_;
    chomp($cmp);
    $base = `basename $cmp .cmp`;
    chomp($base);
    print "Making data, labels, and scp from $base.lab for GV...";
    shell("rm -f $gvdatdir/tmp.cmp");
    shell("touch $gvdatdir/tmp.cmp");
    $i = 0;

    my $dpf = read_cmpfn($cmp);
    my @order = ();
    foreach $type (@cmp) {
      push @order, 3 * $ordr{$type};
    }
    my @dps = streaming_frame($dpf, @order);

    foreach $type (@cmp) {

      open F,">$gvdatdir/$base.$type"; binmode F;
      $refv = shift @dps;

      for ( my $k = 0; $k < @$refv; $k ++ ) {
        for ( my $d = 0; $d < $ordr{$type}; $d ++ ) {
          print F pack "f", $refv->[$k][$d];
        }
      }
      close F;

      if ( $nosilgv && @slnt > 0 ) {
        shell("rm -f $gvdatdir/tmp.$type");
        shell("touch $gvdatdir/tmp.$type");
        open( F, "$gvfaldir/$base.lab" ) || die "Cannot open $!";
        while ( $str = <F> ) {
          chomp($str);
          @arr = split( / /, $str );
          $find = 0;
          for ( $j = 0 ; $j < @slnt ; $j++ ) {
            if ( $arr[2] eq "$slnt[$j]" ) { $find = 1; last; }
          }
          if ( $find == 0 ) {
            $start = int( $arr[0] * ( 1.0e-7 / ( $fs / $sr ) ) );
            $end   = int( $arr[1] * ( 1.0e-7 / ( $fs / $sr ) ) );
            shell("$BCUT -s $start -e $end -l $ordr{$type} < $gvdatdir/$base.$type >> $gvdatdir/tmp.$type");
          }
        }
        shell("rm -f $gvdatdir/$base.$type");
        close(F);
      }
      else {
        shell("mv $gvdatdir/$base.$type $gvdatdir/tmp.$type");
      }
      if ( $msdi{$type} == 0 ) {
        shell("cat      $gvdatdir/tmp.$type                              | $VSTAT -d -l $ordr{$type} -o 2 >> $gvdatdir/tmp.cmp");
      }
      else {
        shell("$X2X +fa $gvdatdir/tmp.$type | grep -v '1e+10' | $X2X +af | $VSTAT -d -l $ordr{$type} -o 2 >> $gvdatdir/tmp.cmp");
      }
      system("rm -f $gvdatdir/tmp.$type");
      $i += 4 * $ordr{$type};
    }
    shell("$PERL $datdir/addhtkheader.pl $sr $fs $i 9 $gvdatdir/tmp.cmp > $gvdatdir/$base.cmp");
    $i = `$NAN $gvdatdir/$base.cmp`;
    chomp($i);
    if ( length($i) > 0 ) {
      shell("rm -f $gvdatdir/$base.cmp");
    }
    else {
      shell("echo $gvdatdir/$base.cmp >> $scp{'gv'}");
      if ($cdgv) {
        open( LAB, "$datdir/labels/full/$base.lab" ) || die "Cannot open $!";
        $str = <LAB>;
        close(LAB);
        chomp($str);
        while ( index( $str, " " ) >= 0 || index( $str, "\t" ) >= 0 ) { substr( $str, 0, 1 ) = ""; }
        open( LAB, "> $gvlabdir/$base.lab" ) || die "Cannot open $!";
        print LAB "$str\n";
        close(LAB);
        print LST "$str\n";
      }
    }
    system("rm -f $gvdatdir/tmp.cmp");
    print "done\n";
  }
  if ($cdgv) {
    close(LST);
    system("sort -u $gvdir/tmp.list > $gvdir/gv.list");
    system("rm -f $gvdir/tmp.list");
  }
  else {
    system("echo gv > $gvdir/gv.list");
  }
  close(SCP);

  # make mlf
  open( MLF, "> $mlf{'gv'}" ) || die "Cannot open $!";
  print MLF "#!MLF!#\n";
  print MLF "\"*/*.lab\" -> \"$gvlabdir\"\n";
  close(MLF);
}

# sub routine to copy average.mmf to full.mmf for GV
sub copy_aver2full_gv {
  my ( $find, $head, $tail, $str );

  $find = 0;
  $head = "";
  $tail = "";
  open( MMF, "$avermmf{'gv'}" ) || die "Cannot open $!";
  while ( $str = <MMF> ) {
    if ( index( $str, "~h" ) >= 0 ) {
      $find = 1;
    }
    elsif ( $find == 0 ) {
      $head .= $str;
    }
    else {
      $tail .= $str;
    }
  }
  close(MMF);
  $head .= `cat $gvdir/vFloors`;
  open( LST, "$gvdir/gv.list" )   || die "Cannot open $!";
  open( MMF, "> $fullmmf{'gv'}" ) || die "Cannot open $!";
  print MMF "$head";
  while ( $str = <LST> ) {
    chomp($str);
    print MMF "~h \"$str\"\n";
    print MMF "$tail";
  }
  close(MMF);
  close(LST);
}

sub copy_aver2clus_gv {
  my ( $find, $head, $mid, $tail, $str, $tmp, $s, @pdfs );

  # initaialize
  $find = 0;
  $head = "";
  $mid  = "";
  $tail = "";
  $s    = 0;
  @pdfs = ();
  foreach $type (@cmp) {
    push( @pdfs, "" );
  }

  # load
  open( MMF, "$avermmf{'gv'}" ) || die "Cannot open $!";
  while ( $str = <MMF> ) {
    if ( index( $str, "~h" ) >= 0 ) {
      $head .= `cat $gvdir/vFloors`;
      last;
    }
    else {
      $head .= $str;
    }
  }
  while ( $str = <MMF> ) {
    if ( index( $str, "<STREAM>" ) >= 0 ) {
      last;
    }
    else {
      $mid .= $str;
    }
  }
  while ( $str = <MMF> ) {
    if ( index( $str, "<TRANSP>" ) >= 0 ) {
      $tail .= $str;
      last;
    }
    elsif ( index( $str, "<STREAM>" ) >= 0 ) {
      $s++;
    }
    else {
      $pdfs[$s] .= $str;
    }
  }
  while ( $str = <MMF> ) {
    $tail .= $str;
  }
  close(MMF);

  # save
  open( MMF, "> $clusmmf{'gv'}" ) || die "Cannot open $!";
  print MMF "$head";
  $s = 1;
  foreach $type (@cmp) {
    print MMF "~p \"gv_${type}_1\"\n";
    print MMF "<STREAM> $s\n";
    print MMF "$pdfs[$s-1]";
    $s++;
  }
  print MMF "~h \"gv\"\n";
  print MMF "$mid";
  $s = 1;
  foreach $type (@cmp) {
    print MMF "<STREAM> $s\n";
    print MMF "~p \"gv_${type}_1\"\n";
    $s++;
  }
  print MMF "$tail";
  close(MMF);
  close(LST);
}

sub copy_clus2clsa_gv {
  shell("cp $clusmmf{'gv'} $clsammf{'gv'}");
  shell("cp $gvdir/gv.list $tiedlst{'gv'}");
}

# sub routine for generating config files
sub make_config {
  my ( $s, $type, @boolstring, $b, $bSize );
  $boolstring[0] = 'FALSE';
  $boolstring[1] = 'TRUE';

  # config file for model training
  open( CONF, ">$cfg{'trn'}" ) || die "Cannot open $!";
  print CONF "APPLYVFLOOR = T\n";
  print CONF "NATURALREADORDER = T\n";
  print CONF "NATURALWRITEORDER = T\n";
  print CONF "VFLOORSCALESTR = \"Vector $nstream{'cmp'}{'total'}";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print CONF " $vflr{$type}";
    }
  }
  print CONF "\"\n";
  printf CONF "DURVARFLOORPERCENTILE = %f\n", 100 * $vflr{'dur'};
  print CONF "APPLYDURVARFLOOR = T\n";
  print CONF "MAXSTDDEVCOEF = $maxdev\n";
  print CONF "MINDUR = $mindur\n";
  close(CONF);

  # config file for model training (without variance flooring)
  open( CONF, ">$cfg{'nvf'}" ) || die "Cannot open $!";
  print CONF "APPLYVFLOOR = F\n";
  print CONF "DURVARFLOORPERCENTILE = 0.0\n";
  print CONF "APPLYDURVARFLOOR = F\n";
  close(CONF);

  # config file for model conversion
  open( CONF, ">$cfg{'cnv'}" ) || die "Cannot open $!";
  print CONF "NATURALREADORDER = T\n";
  print CONF "NATURALWRITEORDER = F\n";    # hts_engine used BIG ENDIAN
  close(CONF);

  # config file for model tying
  foreach $type (@cmp) {
    open( CONF, ">$cfg{$type}" ) || die "Cannot open $!";
    print CONF "MINLEAFOCC = $mocc{$type}\n";
    close(CONF);
  }
  foreach $type (@dur) {
    open( CONF, ">$cfg{$type}" ) || die "Cannot open $!";
    print CONF "MINLEAFOCC = $mocc{$type}\n";
    close(CONF);
  }

  # config file for STC
  open( CONF, ">$cfg{'stc'}" ) || die "Cannot open $!";
  print CONF "MAXSEMITIEDITER = 20\n";
  print CONF "SEMITIEDMACRO   = \"cmp\"\n";
  print CONF "SAVEFULLC = T\n";
  print CONF "BASECLASS = \"$stcbase{'cmp'}\"\n";
  print CONF "TRANSKIND = SEMIT\n";
  print CONF "USEBIAS   = F\n";
  print CONF "ADAPTKIND = BASE\n";
  print CONF "BLOCKSIZE = \"";

  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$bSize ";
      }
    }
  }
  print CONF "\"\n";
  print CONF "BANDWIDTH = \"";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$band{$type} ";
      }
    }
  }
  print CONF "\"\n";
  close(CONF);

  # config file for parameter generation
  open( CONF, ">$cfg{'syn'}" ) || die "Cannot open $!";
  print CONF "NATURALREADORDER = T\n";
  print CONF "NATURALWRITEORDER = T\n";
  print CONF "USEALIGN = T\n";

  print CONF "PDFSTRSIZE = \"IntVec $nPdfStreams{'cmp'}";    # PdfStream structure
  foreach $type (@cmp) {
    print CONF " $nstream{'cmp'}{$type}";
  }
  print CONF "\"\n";

  print CONF "PDFSTRORDER = \"IntVec $nPdfStreams{'cmp'}";    # order of each PdfStream
  foreach $type (@cmp) {
    print CONF " $ordr{$type}";
  }
  print CONF "\"\n";

  print CONF "PDFSTREXT = \"StrVec $nPdfStreams{'cmp'}";      # filename extension for each PdfStream
  foreach $type (@cmp) {
    print CONF " $type";
  }
  print CONF "\"\n";

  print CONF "WINFN = \"";
  foreach $type (@cmp) {
    print CONF "StrVec $nwin{$type} @{$win{$type}} ";        # window coefficients files for each PdfStream
  }
  print CONF "\"\n";
  print CONF "WINDIR = $windir\n";                            # directory which stores window coefficients files

  print CONF "MAXEMITER = $maxEMiter\n";
  print CONF "EMEPSILON = $EMepsilon\n";
  print CONF "USEGV      = $boolstring[$useGV]\n";
  print CONF "GVMODELMMF = $clsammf{'gv'}\n";
  print CONF "GVHMMLIST  = $tiedlst{'gv'}\n";
  print CONF "MAXGVITER  = $maxGViter\n";
  print CONF "GVEPSILON  = $GVepsilon\n";
  print CONF "MINEUCNORM = $minEucNorm\n";
  print CONF "STEPINIT   = $stepInit\n";
  print CONF "STEPINC    = $stepInc\n";
  print CONF "STEPDEC    = $stepDec\n";
  print CONF "HMMWEIGHT  = $hmmWeight\n";
  print CONF "GVWEIGHT   = $gvWeight\n";
  print CONF "OPTKIND    = $optKind\n";

  if ( $nosilgv && @slnt > 0 ) {
    $s = @slnt;
    print CONF "GVOFFMODEL = \"StrVec $s";
    for ( $s = 0 ; $s < @slnt ; $s++ ) {
      print CONF " $slnt[$s]";
    }
    print CONF "\"\n";
  }
  print CONF "CDGV       = $boolstring[$cdgv]\n";

  close(CONF);

  # config file for alignend parameter generation
  open( CONF, ">$cfg{'apg'}" ) || die "Cannot open $!";
  print CONF "MODELALIGN = T\n";
  close(CONF);

}

sub make_config_regtree {

  # config file for building regression tree
  foreach $set (@SET) {
    open( CONF, ">$cfg{'dec'}{$set}" ) || die "Cannot open $!";
    print CONF "SHRINKOCCTHRESH = \"Vector $nstream{$set}{'total'}";
    foreach $type ( @{ $ref{$set} } ) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
        print CONF " $dect{$type}";
      }
    }
    print CONF "\"\n";
    close(CONF);
  }
}

# sub routine for generating config files for adaptation
sub make_config_adapt {
  my ( $s, $b, $type, $bSize );

  # config file for adaptation
  open( CONF, ">$cfg{'adp'}" ) || die "Cannot open $!";
  print CONF "MAXSTDDEVCOEF = 10\n";    # expand max # of state durations
  print CONF "ADAPTKIND    = TREE\n";
  print CONF "DURADAPTKIND = TREE\n";

  print CONF "BASECLASS      = \"$rbase{'cmp'}{$tknd{'adp'}}\"\n";
  print CONF "REGTREE        = \"$rtree{'cmp'}{$tknd{'adp'}}\"\n";
  print CONF "DURBASECLASS   = \"$rbase{'dur'}{$tknd{'adp'}}\"\n";
  print CONF "DURREGTREE     = \"$rtree{'dur'}{$tknd{'adp'}}\"\n";

  # adaptation transform kind
  if ( $tran eq "mean" ) {
    print CONF "TRANSKIND          = MLLRMEAN\n";    # mean transform
    print CONF "USEBIAS            = $bias{'cmp'}\n";
    print CONF "DURTRANSKIND       = MLLRMEAN\n";
    print CONF "DURUSEBIAS         = $bias{'dur'}\n";
    print CONF "MLLRDIAGCOV        = $dcov\n";
    print CONF "USEMAPLR           = $usemaplr\n";
    print CONF "USEVBLR            = $usevblr\n";
    print CONF "USESTRUCTURALPRIOR = $sprior\n";
    print CONF "PRIORSCALE         = $priorscale\n";
  }
  elsif ( $tran eq "cov" ) {
    print CONF "TRANSKIND    = MLLRCOV\n";           # covariance transform
    print CONF "USEBIAS      = FALSE\n";
    print CONF "DURTRANSKIND = MLLRCOV\n";
    print CONF "DURUSEBIAS   = FALSE\n";
    print CONF "MLLRDIAGCOV  = FALSE\n";
  }
  elsif ( $tran eq "feat" ) {
    print CONF "TRANSKIND          = CMLLR\n";       # feature transform
    print CONF "USEBIAS            = $bias{'cmp'}\n";
    print CONF "DURTRANSKIND       = CMLLR\n";
    print CONF "DURUSEBIAS         = $bias{'dur'}\n";
    print CONF "MLLRDIAGCOV        = FALSE\n";
    print CONF "USEMAPLR           = $usemaplr\n";
    print CONF "USESTRUCTURALPRIOR = $sprior\n";
    print CONF "PRIORSCALE         = $priorscale\n";
  }
  else {
    die "MLLR type $tran is not supported!";
  }

  # split threshold for adaptation
  # HMM
  print CONF "SPLITTHRESH = \"Vector $nstream{'cmp'}{'total'}";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print CONF " $adpt{$type}";
    }
  }
  print CONF "\"\n";

  # duration model
  print CONF "DURSPLITTHRESH = \"Vector $nState";
  foreach $type (@dur) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print CONF " $adpt{$type}";
    }
  }
  print CONF "\"\n";

  # block size
  print CONF "BLOCKSIZE   = \"";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$bSize ";
      }
    }
  }
  print CONF "\"\n";

  # band width
  print CONF "BANDWIDTH   = \"";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$band{$type} ";
      }
    }
  }
  print CONF "\"\n";
  close(CONF);

  # config file for MAP adaptation
  open( CONF, ">$cfg{'map'}" ) || die "Cannot open $!";
  print CONF "MAPTAU         = $maptau{'cmp'}\n";
  print CONF "DURMAPTAU      = $maptau{'dur'}\n";
  print CONF "MINEGS         = 1\n";
  print CONF "APPLYVFLOOR    = T\n";
  print CONF "MIXWEIGHTFLOOR = $wf\n";
  print CONF "HMAP:TRACE     = 02\n";
  close(CONF);

  # config file for alignment model
  open( CONF, ">$cfg{'aln'}" ) || die "Cannot open $!";
  if ($addMAP) {
    print CONF "ALIGNMODELMMF = $mapmmf{'cmp'}/re_clustered_all.mmf\n";
    print CONF "ALIGNDURMMF   = $mapmmf{'dur'}/re_clustered_all.mmf\n";
  }
  else {
    print CONF "ALIGNMODELMMF = $rclammf{'cmp'}\n";
    print CONF "ALIGNDURMMF   = $rclammf{'dur'}\n";
  }
  print CONF "ALIGNHMMLIST  = $tiedlst{'cmp'}\n";
  print CONF "ALIGNDURLIST  = $tiedlst{'dur'}\n";
  close(CONF);
}

# sub routine for generating config file for speaker adaptive training
sub make_config_sat {
  my ( $s, $b, $type, $bSize );

  # config file for SAT
  open( CONF, ">$cfg{'sat'}" ) || die "Cannot open $!";
  print CONF "ADAPTKIND    = TREE\n";
  print CONF "DURADAPTKIND = TREE\n";

  print CONF "BASECLASS      = \"$rbase{'cmp'}{$tknd{'sat'}}\"\n";
  print CONF "REGTREE        = \"$rtree{'cmp'}{$tknd{'sat'}}\"\n";
  print CONF "DURBASECLASS   = \"$rbase{'dur'}{$tknd{'sat'}}\"\n";
  print CONF "DURREGTREE     = \"$rtree{'dur'}{$tknd{'sat'}}\"\n";

  # adaptation transform kind
  print CONF "TRANSKIND    = CMLLR\n";    # feature transform
  print CONF "USEBIAS      = $bias{'cmp'}\n";
  print CONF "DURTRANSKIND = CMLLR\n";
  print CONF "DURUSEBIAS   = $bias{'dur'}\n";
  print CONF "MLLRDIAGCOV  = FALSE\n";

  # split threshold for adaptation
  # HMM
  print CONF "SPLITTHRESH = \"Vector $nstream{'cmp'}{'total'}";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print CONF " $satt{$type}";
    }
  }
  print CONF "\"\n";

  # duration model
  print CONF "DURSPLITTHRESH = \"Vector $nState";
  foreach $type (@dur) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      print CONF " $satt{$type}";
    }
  }
  print CONF "\"\n";

  # block size
  print CONF "BLOCKSIZE   = \"";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$bSize ";
      }
    }
  }
  print CONF "\"\n";

  # band width
  print CONF "BANDWIDTH   = \"";
  foreach $type (@cmp) {
    for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
      $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
      print CONF "IntVec $nblk{$type} ";
      for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
        print CONF "$band{$type} ";
      }
    }
  }
  print CONF "\"\n";
  #print CONF "TRACE   = $Trace\n";
  close(CONF);
}

# sub routine for generating .hed files for decision-tree clustering
sub make_edfile_state($$) {
  my ($type, $paral) = @_;
  my ( @lines, $i, %nstate );

  $nstate{'cmp'} = $nState;
  $nstate{'dur'} = 1;

  open( QSFILE, "$qs{$type}" ) || die "Cannot open $!";
  @lines = <QSFILE>;
  close(QSFILE);

  if ( $paral  == 1 || $paral == 2) {
    for ( $i = 2 ; $i <= $nstate{ $t2s{$type} } + 1 ; $i++ ) { # split by state
      open( EDFILE, ">$cxc{$type}.s$i" ) || die "Cannot open $!";
      print EDFILE "// load stats file\n";
      print EDFILE "RO $gam{$type} \"$stats{$t2s{$type}}\"\n\n";
      print EDFILE "TR 0\n\n";
      print EDFILE "// questions for decision tree-based context clustering\n";
      print EDFILE @lines;
      print EDFILE "TR 3\n\n";
      print EDFILE "// construct decision trees\n";

      if ( $durstrcls && $type eq "dur" ) { 
        for ( my $k = $strb{$type}; $k <= $stre{$type}; $k ++ ) {
          my $kk = $k + 1;
          print EDFILE "TB $thr{$type} ${type}_s${kk}_ {*.state[${i}].stream[${k}-${k}]}\n";
        }
      }
      else {
        print EDFILE "TB $thr{$type} ${type}_s${i}_ {*.state[${i}].stream[$strb{$type}-$stre{$type}]}\n";
      }

      print EDFILE "\nTR 1\n\n";
      print EDFILE "// output constructed trees\n";
      print EDFILE "ST \"$tre{$type}.s$i\"\n";
      close(EDFILE);
    }
  }
  else { 
    open( EDFILE, ">$cxc{$type}" ) || die "Cannot open $!";
    print EDFILE "// load stats file\n";
    print EDFILE "RO $gam{$type} \"$stats{$t2s{$type}}\"\n\n";
    print EDFILE "TR 0\n\n";
    print EDFILE "// questions for decision tree-based context clustering\n";
    print EDFILE @lines;
    print EDFILE "TR 3\n\n";
    print EDFILE "// construct decision trees\n";

    for ( $i = 2 ; $i <= $nstate{ $t2s{$type} } + 1 ; $i++ ) {
      if ( $durstrcls && $type eq "dur" ) { 
        for ( my $k = $strb{$type}; $k <= $stre{$type}; $k ++ ) {
          my $kk = $k + 1;
          print EDFILE "TB $thr{$type} ${type}_s${kk}_ {*.state[${i}].stream[${k}-${k}]}\n";
        }
      }
      else {
        print EDFILE "TB $thr{$type} ${type}_s${i}_ {*.state[${i}].stream[$strb{$type}-$stre{$type}]}\n";
      }
    }
    print EDFILE "\nTR 1\n\n";
    print EDFILE "// output constructed trees\n";
    print EDFILE "ST \"$tre{$type}\"\n";
    close(EDFILE);
  }
}

# sub routine for generating .hed files for decision-tree clustering of GV
sub make_edfile_state_gv($$) {
  my ( $type, $s ) = @_;
  my (@lines);

  open( EDFILE, ">$gvcxc{$type}" ) || die "Cannot open $!";
  if ($cdgv) {
    open( QSFILE, "$qs_utt{$type}" ) || die "Cannot open $!";
    @lines = <QSFILE>;
    close(QSFILE);

    print EDFILE "// load stats file\n";
    print EDFILE "RO $gvgam{$type} \"$gvdir/gv.stats\"\n";
    print EDFILE "TR 0\n\n";
    print EDFILE "// questions for decision tree-based context clustering\n";
    print EDFILE @lines;
    print EDFILE "TR 3\n\n";
    print EDFILE "// construct decision trees\n";
    print EDFILE "TB $gvthr{$type} gv_${type}_ {*.state[2].stream[$s]}\n";
    print EDFILE "\nTR 1\n\n";
    print EDFILE "// output constructed trees\n";
    print EDFILE "ST \"$gvtre{$type}\"\n";
  }
  else {
    open( TREE, ">$gvtre{$type}" ) || die "Cannot open $!";
    print TREE " {*}[2].stream[$s]\n   \"gv_${type}_1\"\n";
    close(TREE);
    print EDFILE "// construct tying structure\n";
    print EDFILE "TI gv_${type}_1 {*.state[2].stream[$s]}\n";
  }
  close(EDFILE);
}

# sub routine for untying structures
sub make_edfile_untie($) {
  my ($set) = @_;
  my ( $type, $i, %nstate );

  $nstate{'cmp'} = $nState;
  $nstate{'dur'} = 1;

  open( EDFILE, ">$unt{$set}" ) || die "Cannot open $!";

  print EDFILE "// untie parameter sharing structure\n";
  foreach $type ( @{ $ref{$set} } ) {
    for ( $i = 2 ; $i <= $nstate{$set} + 1 ; $i++ ) {
      if ( $#{ $ref{$set} } eq 0 ) {
        if ( $durstrcls && $type eq "dur" ) {
          for ( my $k = $strb{$type}; $k <= $stre{$type}; $k ++ ) {
            print EDFILE "UT {*.state[$i].stream[$k-$k]}\n";
          }
        }
        else {
          print EDFILE "UT {*.state[$i]}\n";
        }
      }
      else {
        if ( $strw{$type} > 0.0 ) {
          print EDFILE "UT {*.state[$i].stream[$strb{$type}-$stre{$type}]}\n";
        }
      }
    }
  }

  close(EDFILE);
}

# sub routine to increase the number of mixture components
sub make_edfile_upmix($) {
  my ($set) = @_;
  my ( $type, $i, @nstate );

  $nstate{'cmp'} = $nState;
  $nstate{'dur'} = 1;

  open( EDFILE, ">$upm{$set}" ) || die "Cannot open $!";

  print EDFILE "// increase the number of mixtures per stream\n";
  foreach $type ( @{ $ref{$set} } ) {
    for ( $i = 2 ; $i <= $nstate{$set} + 1 ; $i++ ) {
      if ( $#{ $ref{$set} } eq 0 ) {
        print EDFILE "MU +1 {*.state[$i].mix}\n";
      }
      else {
        print EDFILE "MU +1 {*.state[$i].stream[$strb{$type}-$stre{$type}].mix}\n";
      }
    }
  }

  close(EDFILE);
}

# sub routine to convert statistics file for cmp into one for dur
sub convstats {
  open( IN,  "$stats{'cmp'}" )  || die "Cannot open $!";
  open( OUT, ">$stats{'dur'}" ) || die "Cannot open $!";
  while (<IN>) {
    @LINE = split(' ');
    printf OUT ( "%4d %14s %4d %4d\n", $LINE[0], $LINE[1], $LINE[2], $LINE[2] );
  }
  close(IN);
  close(OUT);
}

# sub routine for generating .hed files for mmf -> hts_engine conversion
sub make_edfile_convert($$) {
  my ($type,$spxf) = @_;
  my ( $i, %nstate );

  $nstate{'cmp'} = $nState;
  $nstate{'mgc'} = $nState;
  $nstate{'lf0'} = $nState;
  $nstate{'bap'} = $nState;
  $nstate{'dur'} = 1;

  open( EDFILE, ">$cnv{$type}" ) || die "Cannot open $!";
  print EDFILE "\nTR 2\n\n";
  print EDFILE "// load adaptation transforms\n";
  print EDFILE "AX \"$spxf\"\n";
  print EDFILE "// load trees for $type\n";
  if ( $paral == 1 || $paral == 2 ) {
    for ( $i = 2 ; $i <= $nstate{ $t2s{$type} } + 1 ; $i++ ) { 
      print EDFILE "LT \"$tre{$type}.s$i\"\n\n";
    }
  }
  else {
    print EDFILE "fuck paral = $paral\n";
    print EDFILE "LT \"$tre{$type}\"\n\n";
  }

  print EDFILE "// convert loaded trees for hts_engine format\n";
  print EDFILE "CT \"$trd{$t2s{$type}}\"\n\n";

  print EDFILE "// convert mmf for hts_engine format\n";
  print EDFILE "CM \"$model{$t2s{$type}}\"\n";

  close(EDFILE);
}

# sub routine for generating .hed files for GV mmf -> hts_engine conversion
sub make_edfile_convert_gv($) {
  my ($type) = @_;

  open( EDFILE, ">$gvcnv{$type}" ) || die "Cannot open $!";
  print EDFILE "\nTR 2\n\n";
  print EDFILE "// load trees for $type\n";
  print EDFILE "LT \"$gvdir/$type.inf\"\n\n";

  print EDFILE "// convert loaded trees for hts_engine format\n";
  print EDFILE "CT \"$gvdir\"\n\n";

  print EDFILE "// convert mmf for hts_engine format\n";
  print EDFILE "CM \"$gvdir\"\n";

  close(EDFILE);
}

# sub routine for generating .hed files for making unseen models
sub make_edfile_mkunseen($) {
  my ($set) = @_;
  my ($type);

  $nstate{'mgc'} = $nState;
  $nstate{'lf0'} = $nState;
  $nstate{'bap'} = $nState;
  $nstate{'dur'} = 1;
  open( EDFILE, ">$mku{$set}" ) || die "Cannot open $!";
  print EDFILE "\nTR 2\n\n";
  foreach $type ( @{ $ref{$set} } ) {
    print EDFILE "// load trees for $type\n";
    # edited by bc299@20170723
    for ( $i = 2 ; $i <= $nstate{ $type } + 1 ; $i++ ) {
      print EDFILE "LT \"$tre{$type}.s$i\"\n\n"; #orig
    }
    #print EDFILE "LT \"$tre{$type}\"\n\n";
  }

  print EDFILE "// make unseen model\n";
  print EDFILE "AU \"$lst{'all'}\"\n\n";
  print EDFILE "// make model compact\n";
  print EDFILE "CO \"$tiedlst{$set}\"\n\n";

  close(EDFILE);
}

# sub routine for generating .hed files for constructing a regression tree
sub make_edfile_regtree($$) {
  my ( $regtype, $set ) = @_;
  my ($type);

  $nstate{'mgc'} = $nState;
  $nstate{'lf0'} = $nState;
  $nstate{'bap'} = $nState;
  $nstate{'dur'} = 1;
  open( EDFILE, ">$red{$set}{$regtype}" ) || die "Cannot open $!";
  if ( $regtype eq 'reg' ) {
    print EDFILE "// load stats file\n";
    print EDFILE "LS \"$stats{$set}\"\n";
    print EDFILE "// construct regression class tree\n";
    print EDFILE "RC $nClass \"$regtype\"\n";
  }
  else {
    print EDFILE "// load stats file\n";
    print EDFILE "LS \"$stats{$set}\"\n";
    foreach $type ( @{ $ref{$set} } ) {
      print EDFILE "// load trees for $type\n";
      # edited by bc299@20170723
      for ( $i = 2 ; $i <= $nstate{ $type } + 1 ; $i++ ) {
        print EDFILE "LT \"$tre{$type}.s$i\"\n\n"; #orig
      }
      #print EDFILE "LT \"$tre{$type}\"\n\n"; #orig
    }
    print EDFILE "// convert decision trees to a regression class tree\n";
    print EDFILE "DR \"$regtype\"\n";
  }
  close(EDFILE);
}

# sub routine for generating .hed files for making unseen models for GV
sub make_edfile_mkunseen_gv {
  my ($type);

  open( EDFILE, ">$mku{'gv'}" ) || die "Cannot open $!";
  print EDFILE "\nTR 2\n\n";
  foreach $type (@cmp) {
    print EDFILE "// load trees for $type\n";
    print EDFILE "LT \"$gvtre{$type}\"\n\n";
  }

  print EDFILE "// make unseen model\n";
  print EDFILE "AU \"$lst{'all'}\"\n\n";
  print EDFILE "// make model compact\n";
  print EDFILE "CO \"$tiedlst{'gv'}\"\n\n";

  close(EDFILE);
}

# sub routine for generating low pass filter of hts_engine API
sub make_lpf {
  my ( $lfil, @coef, $coefSize, $i, $j );

  $lfil     = `$PERL makefilter.pl $sr 0`;
  @coef     = split( '\s', $lfil );
  $coefSize = @coef;

  shell("rm -f $pdf{'lpf'}");
  shell("touch $pdf{'lpf'}");
  for ( $i = 0 ; $i < $nState ; $i++ ) {
    shell("echo 1 | $X2X +ai >> $pdf{'lpf'}");
  }
  for ( $i = 0 ; $i < $nState ; $i++ ) {
    for ( $j = 0 ; $j < $coefSize ; $j++ ) {
      shell("echo $coef[$j] | $X2X +af >> $pdf{'lpf'}");
    }
    for ( $j = 0 ; $j < $coefSize ; $j++ ) {
      shell("echo 0.0 | $X2X +af >> $pdf{'lpf'}");
    }
  }

  open( INF, "> $trv{'lpf'}" );
  for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
    print INF "{*}[${i}]\n";
    print INF "   \"lpf_s${i}_1\"\n";
  }
  close(INF);

  open( WIN, "> $voice/lpf.win1" );
  print WIN "1 1.0\n";
  close(WIN);
}

# sub routine for generating HTS voice for hts_engine API
sub make_htsvoice($$) {
  my ( $voicedir, $voicename ) = @_;
  my ( $i, $type, $tmp, @coef, $coefSize, $file_index, $s, $e );

  open( HTSVOICE, "> ${voicedir}/${voicename}.htsvoice" );

  # global information
  print HTSVOICE "[GLOBAL]\n";
  print HTSVOICE "HTS_VOICE_VERSION:1.0\n";
  print HTSVOICE "SAMPLING_FREQUENCY:${sr}\n";
  print HTSVOICE "FRAME_PERIOD:${fs}\n";
  print HTSVOICE "NUM_STATES:${nState}\n";
  print HTSVOICE "NUM_STREAMS:" . ( ${ nPdfStreams { 'cmp' } } + 1 ) . "\n";
  print HTSVOICE "STREAM_TYPE:";

  for ( $i = 0 ; $i < @cmp ; $i++ ) {
    if ( $i != 0 ) {
      print HTSVOICE ",";
    }
    $tmp = get_stream_name( $cmp[$i] );
    print HTSVOICE "${tmp}";
  }
  print HTSVOICE ",LPF\n";
  print HTSVOICE "FULLCONTEXT_FORMAT:${fclf}\n";
  print HTSVOICE "FULLCONTEXT_VERSION:${fclv}\n";
  if ($nosilgv) {
    print HTSVOICE "GV_OFF_CONTEXT:";
    for ( $i = 0 ; $i < @slnt ; $i++ ) {
      if ( $i != 0 ) {
        print HTSVOICE ",";
      }
      print HTSVOICE "\"*-${slnt[$i]}+*\"";
    }
  }
  print HTSVOICE "\n";
  print HTSVOICE "COMMENT:\n";

  # stream information
  print HTSVOICE "[STREAM]\n";
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    print HTSVOICE "VECTOR_LENGTH[${tmp}]:${ordr{$type}}\n";
  }
  $type     = "lpf";
  $tmp      = get_stream_name($type);
  @coef     = split( '\s', `$PERL $datdir/scripts/makefilter.pl $sr 0` );
  $coefSize = @coef;
  print HTSVOICE "VECTOR_LENGTH[${tmp}]:${coefSize}\n";
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    print HTSVOICE "IS_MSD[${tmp}]:${msdi{$type}}\n";
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  print HTSVOICE "IS_MSD[${tmp}]:0\n";
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    print HTSVOICE "NUM_WINDOWS[${tmp}]:${nwin{$type}}\n";
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  print HTSVOICE "NUM_WINDOWS[${tmp}]:1\n";
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ($useGV) {
      print HTSVOICE "USE_GV[${tmp}]:1\n";
    }
    else {
      print HTSVOICE "USE_GV[${tmp}]:0\n";
    }
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  print HTSVOICE "USE_GV[${tmp}]:0\n";
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ( $tmp eq "MCP" ) {
      print HTSVOICE "OPTION[${tmp}]:ALPHA=$fw\n";
    }
    elsif ( $tmp eq "LSP" ) {
      print HTSVOICE "OPTION[${tmp}]:ALPHA=$fw,GAMMA=$gm,LN_GAIN=$lg\n";
    }
    else {
      print HTSVOICE "OPTION[${tmp}]:\n";
    }
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  print HTSVOICE "OPTION[${tmp}]:\n";

  # position
  $file_index = 0;
  print HTSVOICE "[POSITION]\n";
  $file_size = get_file_size("${voicedir}/dur.pdf");
  $s         = $file_index;
  $e         = $file_index + $file_size - 1;
  print HTSVOICE "DURATION_PDF:${s}-${e}\n";
  $file_index += $file_size;
  $file_size = get_file_size("${voicedir}/tree-dur.inf");
  $s         = $file_index;
  $e         = $file_index + $file_size - 1;
  print HTSVOICE "DURATION_TREE:${s}-${e}\n";
  $file_index += $file_size;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    print HTSVOICE "STREAM_WIN[${tmp}]:";
    for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
      $file_size = get_file_size("${voicedir}/$win{$type}[$i]");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      if ( $i != 0 ) {
        print HTSVOICE ",";
      }
      print HTSVOICE "${s}-${e}";
      $file_index += $file_size;
    }
    print HTSVOICE "\n";
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  print HTSVOICE "STREAM_WIN[${tmp}]:";
  $file_size = get_file_size("$voicedir/$win{$type}[0]");
  $s         = $file_index;
  $e         = $file_index + $file_size - 1;
  print HTSVOICE "${s}-${e}";
  $file_index += $file_size;
  print HTSVOICE "\n";

  foreach $type (@cmp) {
    $tmp       = get_stream_name($type);
    $file_size = get_file_size("${voicedir}/${type}.pdf");
    $s         = $file_index;
    $e         = $file_index + $file_size - 1;
    print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
    $file_index += $file_size;
  }
  $type      = "lpf";
  $tmp       = get_stream_name($type);
  $file_size = get_file_size("${voicedir}/${type}.pdf");
  $s         = $file_index;
  $e         = $file_index + $file_size - 1;
  print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
  $file_index += $file_size;

  foreach $type (@cmp) {
    $tmp       = get_stream_name($type);
    $file_size = get_file_size("${voicedir}/tree-${type}.inf");
    $s         = $file_index;
    $e         = $file_index + $file_size - 1;
    print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
    $file_index += $file_size;
  }
  $type      = "lpf";
  $tmp       = get_stream_name($type);
  $file_size = get_file_size("${voicedir}/tree-${type}.inf");
  $s         = $file_index;
  $e         = $file_index + $file_size - 1;
  print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
  $file_index += $file_size;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ($useGV) {
      $file_size = get_file_size("${voicedir}/gv-${type}.pdf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "GV_PDF[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
    }
  }
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ( $useGV && $cdgv ) {
      $file_size = get_file_size("${voicedir}/tree-gv-${type}.inf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "GV_TREE[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
    }
  }

  # data information
  print HTSVOICE "[DATA]\n";
  open( I, "${voicedir}/dur.pdf" ) || die "Cannot open $!";
  @STAT = stat(I);
  read( I, $DATA, $STAT[7] );
  close(I);
  print HTSVOICE $DATA;
  open( I, "${voicedir}/tree-dur.inf" ) || die "Cannot open $!";
  @STAT = stat(I);
  read( I, $DATA, $STAT[7] );
  close(I);
  print HTSVOICE $DATA;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
      open( I, "${voicedir}/$win{$type}[$i]" ) || die "Cannot open $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
    }
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  open( I, "${voicedir}/$win{$type}[0]" ) || die "Cannot open $!";
  @STAT = stat(I);
  read( I, $DATA, $STAT[7] );
  close(I);
  print HTSVOICE $DATA;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    open( I, "${voicedir}/${type}.pdf" ) || die "Cannot open $!";
    @STAT = stat(I);
    read( I, $DATA, $STAT[7] );
    close(I);
    print HTSVOICE $DATA;
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  open( I, "${voicedir}/${type}.pdf" ) || die "Cannot open $!";
  @STAT = stat(I);
  read( I, $DATA, $STAT[7] );
  close(I);
  print HTSVOICE $DATA;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    open( I, "${voicedir}/tree-${type}.inf" ) || die "Cannot open $!";
    @STAT = stat(I);
    read( I, $DATA, $STAT[7] );
    close(I);
    print HTSVOICE $DATA;
  }
  $type = "lpf";
  $tmp  = get_stream_name($type);
  open( I, "${voicedir}/tree-${type}.inf" ) || die "Cannot open $!";
  @STAT = stat(I);
  read( I, $DATA, $STAT[7] );
  close(I);
  print HTSVOICE $DATA;

  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ($useGV) {
      open( I, "${voicedir}/gv-${type}.pdf" ) || die "Cannot open $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
    }
  }
  foreach $type (@cmp) {
    $tmp = get_stream_name($type);
    if ( $useGV && $cdgv ) {
      open( I, "${voicedir}/tree-gv-${type}.inf" ) || die "Cannot open $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
    }
  }
  close(HTSVOICE);
}

# sub routine for getting stream name for HTS voice
sub get_stream_name($) {
  my ($from) = @_;
  my ($to);

  if ( $from eq 'mgc' ) {
    if ( $gm == 0 ) {
      $to = "MCP";
    }
    else {
      $to = "LSP";
    }
  }
  else {
    $to = uc $from;
  }

  return $to;
}

# sub routine for getting file size
sub get_file_size($) {
  my ($file) = @_;
  my ($file_size);

  $file_size = `$WC -c < $file`;
  chomp($file_size);

  return $file_size;
}

# sub routine for formant emphasis in Mel-cepstral domain
sub postfiltering_mcp($$) {
  my ( $base, $gendir ) = @_;
  my ( $i, $line );

  # output postfiltering weight coefficient
  $line = "echo 1 1 ";
  for ( $i = 2 ; $i < $ordr{'mgc'} ; $i++ ) {
    $line .= "$pf_mcp ";
  }
  $line .= "| $X2X +af > $gendir/weight";
  shell($line);

  # calculate auto-correlation of original mcep
  $line = "$FREQT -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -M $co -A 0 < $gendir/${base}.mgc | ";
  $line .= "$C2ACR -m $co -M 0 -l $fl > $gendir/${base}.r0";
  shell($line);

  # calculate auto-correlation of postfiltered mcep
  $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
  $line .= "$FREQT -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -M $co -A 0 | ";
  $line .= "$C2ACR -m $co -M 0 -l $fl > $gendir/${base}.p_r0";
  shell($line);

  # calculate MLSA coefficients from postfiltered mcep
  $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
  $line .= "$MC2B -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw | ";
  $line .= "$BCP -n " .  ( $ordr{'mgc'} - 1 ) . " -s 0 -e 0 > $gendir/${base}.b0";
  shell($line);

  # calculate 0.5 * log(acr_orig/acr_post)) and add it to 0th MLSA coefficient
  $line = "$VOPR -d < $gendir/${base}.r0 $gendir/${base}.p_r0 | ";
  $line .= "$SOPR -LN -d 2 | ";
  $line .= "$VOPR -a $gendir/${base}.b0 > $gendir/${base}.p_b0";
  shell($line);

  # generate postfiltered mcep
  $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
  $line .= "$MC2B -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw | ";
  $line .= "$BCP -n " .   ( $ordr{'mgc'} - 1 ) . " -s 1 -e " . ( $ordr{'mgc'} - 1 ) . " | ";
  $line .= "$MERGE -n " . ( $ordr{'mgc'} - 2 ) . " -s 0 -N 0 $gendir/${base}.p_b0 | ";
  $line .= "$B2MC -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw > $gendir/${base}.p_mgc";
  shell($line);
}

# sub routine for formant emphasis in LSP domain
sub postfiltering_lsp($$) {
  my ( $base, $gendir ) = @_;
  my ( $file, $lgopt, $line, $i, @lsp, $d_1, $d_2, $plsp, $data );

  $file = "$gendir/${base}.mgc";
  if ($lg) {
    $lgopt = "-L";
  }
  else {
    $lgopt = "";
  }

  $line = "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $file | ";
  $line .= "$LSP2LPC -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
  $line .= "$MGC2MGC -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
  $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $gendir/${base}.ene1";
  shell($line);

  # postfiltering
  open( LSP,  "$X2X +fa < $gendir/${base}.mgc |" );
  open( GAIN, ">$gendir/${base}.gain" );
  open( PLSP, ">$gendir/${base}.lsp" );
  while (1) {
    @lsp = ();
    for ( $i = 0 ; $i < $ordr{'mgc'} && ( $line = <LSP> ) ; $i++ ) {
      push( @lsp, $line );
    }
    if ( $ordr{'mgc'} != @lsp ) { last; }

    $data = pack( "f", $lsp[0] );
    print GAIN $data;
    for ( $i = 1 ; $i < $ordr{'mgc'} ; $i++ ) {
      if ( $i > 1 && $i < $ordr{'mgc'} - 1 ) {
        $d_1 = $pf_lsp * ( $lsp[ $i + 1 ] - $lsp[$i] );
        $d_2 = $pf_lsp * ( $lsp[$i] - $lsp[ $i - 1 ] );
        $plsp = $lsp[ $i - 1 ] + $d_2 + ( $d_2 * $d_2 * ( ( $lsp[ $i + 1 ] - $lsp[ $i - 1 ] ) - ( $d_1 + $d_2 ) ) ) / ( ( $d_2 * $d_2 ) + ( $d_1 * $d_1 ) );
      }
      else {
        $plsp = $lsp[$i];
      }
      $data = pack( "f", $plsp );
      print PLSP $data;
    }
  }
  close(PLSP);
  close(GAIN);
  close(LSP);

  $line = "$MERGE -s 1 -l 1 -L " . ( $ordr{'mgc'} - 1 ) . " -N " . ( $ordr{'mgc'} - 2 ) . " $gendir/${base}.lsp < $gendir/${base}.gain | ";
  $line .= "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 | ";
  $line .= "$LSP2LPC -m " .  ( $ordr{'mgc'} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt | ";
  $line .= "$MGC2MGC -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
  $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $gendir/${base}.ene2 ";
  shell($line);

  $line = "$VOPR -l 1 -d $gendir/${base}.ene2 $gendir/${base}.ene2 | $SOPR -LN -m 0.5 | ";
  $line .= "$VOPR -a $gendir/${base}.gain | ";
  $line .= "$MERGE -s 1 -l 1 -L " . ( $ordr{'mgc'} - 1 ) . " -N " . ( $ordr{'mgc'} - 2 ) . " $gendir/${base}.lsp > $gendir/${base}.p_mgc";
  shell($line);

  $line = "rm -f $gendir/${base}.ene1 $gendir/${base}.ene2 $gendir/${base}.gain $gendir/${base}.lsp";
  shell($line);
}

# sub routine for speech synthesis from log f0 and Mel-cepstral coefficients
sub gen_wave($) {
  my ($gendir) = @_;
  my ( $line, @FILE, $lgopt, $file, $base, $T, $lf0, $bap );

  $line = `ls $gendir/*.mgc`;
  @FILE = split( '\n', $line );
  if ($lg) {
    $lgopt = "-L";
  }
  else {
    $lgopt = "";
  }
  print "Processing directory $gendir:\n";
  foreach $file (@FILE) {
    $base = `basename $file .mgc`;
    chomp($base);

    if ( $gm == 0 ) {

      # apply postfiltering
      if ($useMSPF) {
        postfiltering_mspf( $base, $gendir, 'mgc' );
        $mgc = "$gendir/$base.p_mgc";
      }
      elsif ( !$useGV && $pf_mcp != 1.0 ) {
        postfiltering_mcp( $base, $gendir );
        $mgc = "$gendir/$base.p_mgc";
      }
      else {
        $mgc = $file;
      }
    }
    else {

      # apply postfiltering
      if ($useMSPF) {
        postfiltering_mspf( $base, $gendir, 'mgc' );
        $mgc = "$gendir/$base.p_mgc";
      }
      elsif ( !$useGV && $pf_lsp != 1.0 ) {
        postfiltering_lsp( $base, $gendir );
        $mgc = "$gendir/$base.p_mgc";
      }
      else {
        $mgc = $file;
      }

      # MGC-LSPs -> MGC coefficients
      $line = "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $mgc | ";
      $line .= "$LSP2LPC -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
      $line .= "$MGC2MGC -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $ordr{'mgc'} - 1 ) . " -A $fw -C $gm " . " > $gendir/$base.c_mgc";
      shell($line);

      $mgc = "$gendir/$base.c_mgc";
    }

    $lf0 = "$gendir/$base.lf0";
    $bap = "$gendir/$base.bap";

    if ( !$usestraight && -s $file && -s $lf0 ) {
      print " Synthesizing a speech waveform from $base.mgc and $base.lf0...";

      # convert log F0 to pitch
      $line = "$SOPR -magic -1.0E+10 -EXP -INV -m $sr -MAGIC 0.0 $lf0 > $gendir/${base}.pit";
      shell($line);

      # synthesize waveform
      $lfil = `$PERL $datdir/scripts/makefilter.pl $sr 0`;
      $hfil = `$PERL $datdir/scripts/makefilter.pl $sr 1`;

      $line = "$SOPR -m 0 $gendir/$base.pit | $EXCITE -n -p $fs | $DFS -b $hfil > $gendir/$base.unv";
      shell($line);

      $line = "$EXCITE -n -p $fs $gendir/$base.pit | ";
      $line .= "$DFS -b $lfil | $VOPR -a $gendir/$base.unv | ";
      $line .= "$MGLSADF -P 5 -m " . ( $ordr{'mgc'} - 1 ) . " -p $fs -a $fw -c $gm $mgc | ";
      $line .= "$X2X +fs -o > $gendir/$base.raw";
      shell($line);
      $line = "$RAW2WAV -s " . ( $sr / 1000 ) . " -d $gendir $gendir/$base.raw";
      shell($line);

      $line = "rm -f $gendir/$base.unv";
      shell($line);

      print "done\n";
    }
    elsif ( $usestraight && -s $file && -s $lf0 && -s $bap ) {
      print " Synthesizing a speech waveform from $base.mgc, $base.lf0, and $base.bap... ";

      # convert log F0 to F0
      $line = "$SOPR -magic -1.0E+10 -EXP -MAGIC 0.0 $lf0 > $gendir/${base}.f0 ";
      shell($line);
      $T = get_file_size("$gendir/${base}.f0 ") / 4;

      # convert Mel-cepstral coefficients to spectrum
      if ( $gm == 0 ) {
        shell( "$MGC2SP -a $fw -g $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $mgc > $gendir/$base.sp" );
      }
      else {
        shell( "$MGC2SP -a $fw -c $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $mgc > $gendir/$base.sp" );
      }

      # convert band-aperiodicity to aperiodicity
      shell( "$MGC2SP -a $fw -g 0 -m " . ( $ordr{'bap'} - 1 ) . " -l 2048 -o 0 $bap > $gendir/$base.ap" );

      # synthesize waveform
      open( SYN, ">$gendir/${base}.m" ) || die "Cannot open $!";
      printf SYN "path(path,'%s');\n",                 ${STRAIGHT};
      printf SYN "prm.spectralUpdateInterval = %f;\n", 1000.0 * $fs / $sr;
      printf SYN "prm.levelNormalizationIndicator = 0;\n\n";
      printf SYN "fprintf(1,'\\nSynthesizing %s\\n');\n", "$gendir/$base.wav";
      printf SYN "fid1 = fopen('%s','r','%s');\n",        "$gendir/$base.sp", "ieee-le";
      printf SYN "fid2 = fopen('%s','r','%s');\n",        "$gendir/$base.ap", "ieee-le";
      printf SYN "fid3 = fopen('%s','r','%s');\n",        "$gendir/$base.f0", "ieee-le";
      printf SYN "sp = fread(fid1,[%d, %d],'float');\n",  1025, $T;
      printf SYN "ap = fread(fid2,[%d, %d],'float');\n",  1025, $T;
      printf SYN "f0 = fread(fid3,[%d, %d],'float');\n",  1, $T;
      printf SYN "fclose(fid1);\n";
      printf SYN "fclose(fid2);\n";
      printf SYN "fclose(fid3);\n";
      printf SYN "sp = sp/32768.0;\n";
      printf SYN "[sy] = exstraightsynth(f0,sp,ap,%d,prm);\n", $sr;
      printf SYN "wavwrite( sy, %d, '%s');\n\n", $sr, "$gendir/$base.wav";
      printf SYN "quit;\n";
      close(SYN);
      shell("$MATLAB < $gendir/${base}.m");

      $line = "rm -f $gendir/$base.m";
      shell($line);

      print "done\n";
    }
  }
}

# sub routine for modulation spectrum-based postfilter
sub postfiltering_mspf($$$) {
  my ( $base, $gendir, $type ) = @_;
  my ( $gentype, $T, $line, $d, @seq );

  $gentype = $gendir;
  $gentype =~ s/$prjdir\/gen\/qst$qnum\/ver$ver\/+/gen\//g;
  $T = get_file_size("$gendir/$base.$type") / $ordr{$type} / 4;

  # subtract utterance-level mean
  $line = get_cmd_utmean( "$gendir/$base.$type", $type );
  shell("$line > $gendir/$base.$type.mean");
  $line = get_cmd_vopr( "$gendir/$base.$type", "-s", "$gendir/$base.$type.mean", $type );
  shell("$line > $gendir/$base.$type.subtracted");

  for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {

    # calculate modulation spectrum/phase
    $line = get_cmd_seq2ms( "$gendir/$base.$type.subtracted", $type, $d );
    shell("$line > $gendir/$base.$type.mspec_dim$d");
    $line = get_cmd_seq2mp( "$gendir/$base.$type.subtracted", $type, $d );
    shell("$line > $gendir/$base.$type.mphase_dim$d");

    # convert
    $line = "cat $gendir/$base.$type.mspec_dim$d | ";
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $mspfmean{$type}{$gentype}[$d] | ";
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $mspfstdd{$type}{$gentype}[$d] | ";
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -m $mspfstdd{$type}{'nat'}[$d] | ";
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $mspfmean{$type}{'nat'}[$d] | ";

    # apply weight
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $gendir/$base.$type.mspec_dim$d | ";
    $line .= "$SOPR -m $mspfe{$type} | ";
    $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $gendir/$base.$type.mspec_dim$d > $gendir/$base.p_$type.mspec_dim$d";
    shell($line);

    # calculate filtered sequence
    push( @seq, msmp2seq( "$gendir/$base.p_$type.mspec_dim$d", "$gendir/$base.$type.mphase_dim$d", $T ) );
  }
  open( SEQ, ">$gendir/$base.tmp" ) || die "Cannot open $!";
  print SEQ join( "\n", @seq );
  close(SEQ);
  shell("$X2X +af $gendir/$base.tmp | $TRANSPOSE -m $ordr{$type} -n $T > $gendir/$base.p_$type.subtracted");

  # add utterance-level mean
  $line = get_cmd_vopr( "$gendir/$base.p_$type.subtracted", "-a", "$gendir/$base.$type.mean", $type );
  shell("$line > $gendir/$base.p_$type");

  # remove temporal files
  shell("rm -f $gendir/$base.$type.mspec_dim* $gendir/$base.$type.mphase_dim* $gendir/$base.p_$type.mspec_dim*");
  shell("rm -f $gendir/$base.$type.subtracted $gendir/$base.p_$type.subtracted $gendir/$base.$type.mean $gendir/$base.$type.tmp");
}

# sub routine for calculating temporal sequence from modulation spectrum/phase
sub msmp2seq($$$) {
  my ( $file_ms, $file_mp, $T ) = @_;
  my ( @msp, @seq, @wseq, @ms, @mp, $d, $pos, $bias, $mspfShift );

  @ms = split( /\n/, `$SOPR -EXP  $file_ms | $X2X +fa` );
  @mp = split( /\n/, `$SOPR -m pi $file_mp | $X2X +fa` );
  $mspfShift = ( $mspfLength - 1 ) / 2;

  # ifft (modulation spectrum & modulation phase -> temporal sequence)
  for ( $pos = 0, $bias = 0 ; $pos <= $#ms ; $pos += $mspfFFTLen / 2 + 1 ) {
    for ( $d = 0 ; $d <= $mspfFFTLen / 2 ; $d++ ) {
      $msp[ $d + $bias ] = $ms[ $d + $pos ] * cos( $mp[ $d + $pos ] );
      $msp[ $d + $mspfFFTLen + $bias ] = $ms[ $d + $pos ] * sin( $mp[ $d + $pos ] );
      if ( $d != 0 && $d != $mspfFFTLen / 2 ) {
        $msp[ $mspfFFTLen - $d + $bias ] = $msp[ $d + $bias ];
        $msp[ 2 * $mspfFFTLen - $d + $bias ] = -$msp[ $d + $mspfFFTLen + $bias ];
      }
    }
    $bias += 2 * $mspfFFTLen;
  }
  open( MSP, ">$file_ms.tmp" ) || die "Cannot open $!";
  print MSP join( "\n", @msp );
  close(MSP);
  @wseq = split( "\n", `$X2X +af $file_ms.tmp | $IFFTR -l $mspfFFTLen | $X2X +fa` );
  shell("rm -f $file_ms.tmp");

  # overlap-addition
  for ( $pos = 0, $bias = 0 ; $pos <= $#wseq ; $pos += $mspfFFTLen ) {
    for ( $d = 0 ; $d < $mspfFFTLen ; $d++ ) {
      $seq[ $d + $bias ] += $wseq[ $d + $pos ];
    }
    $bias += $mspfShift;
  }

  return @seq[ $mspfShift .. ( $T + $mspfShift - 1 ) ];
}

# sub routine for shell command to get utterance mean
sub get_cmd_utmean($$) {
  my ( $file, $type ) = @_;

  return "$VSTAT -l $ordr{$type} -o 1 < $file ";
}

# sub routine for shell command to subtract vector from sequence
sub get_cmd_vopr($$$$) {
  my ( $file, $opt, $vec, $type ) = @_;
  my ( $value, $line );

  if ( $ordr{$type} == 1 ) {
    $value = `$X2X +fa < $vec`;
    chomp($value);
    $line = "$SOPR $opt $value < $file ";
  }
  else {
    $line = "$VOPR -l $ordr{$type} $opt $vec < $file ";
  }
  return $line;
}

# sub routine for shell command to calculate modulation spectrum from sequence
sub get_cmd_seq2ms($$$) {
  my ( $file, $type, $d ) = @_;
  my ( $T, $line, $mspfShift );

  $T         = get_file_size("$file") / $ordr{$type} / 4;
  $mspfShift = ( $mspfLength - 1 ) / 2;

  $line = "$BCP -l $ordr{$type} -L 1 -s $d -e $d < $file | ";
  $line .= "$WINDOW -l $T -L " . ( $T + $mspfShift ) . " -n 0 -w 5 | ";
  $line .= "$FRAME -l $mspfLength -p $mspfShift | ";
  $line .= "$WINDOW -l $mspfLength -L $mspfFFTLen -n 0 -w 3 | ";
  $line .= "$SPEC -l $mspfFFTLen -o 1 -e 1e-30 ";

  return $line;
}

# sub routine for shell command to calculate modulation phase from sequence
sub get_cmd_seq2mp($$$) {
  my ( $file, $type, $d ) = @_;
  my ( $T, $line, $mspfShift );

  $T         = get_file_size("$file") / $ordr{$type} / 4;
  $mspfShift = ( $mspfLength - 1 ) / 2;

  $line = "$BCP -l $ordr{$type} -L 1 -s $d -e $d < $file | ";
  $line .= "$WINDOW -l $T -L " . ( $T + $mspfShift ) . " -n 0 -w 5 | ";
  $line .= "$FRAME -l $mspfLength -p $mspfShift | ";
  $line .= "$WINDOW -l $mspfLength -L $mspfFFTLen -n 0 -w 3 | ";
  $line .= "$PHASE -l $mspfFFTLen -u ";

  return $line;
}

# sub routine for making force-aligned label files
sub make_full_fal() {
  my ( $line, $base, $istr, $lstr, @iarr, @larr );

  open( ISCP, "$scp{'trn'}" )   || die "Cannot open $!";
  open( OSCP, ">$scp{'mspf'}" ) || die "Cannot open $!";

  while (<ISCP>) {
    $line = $_;
    chomp($line);
    $base = `basename $line .cmp`;
    chomp($base);

    open( LAB,  "$datdir/labels/full/$base.lab" ) || die "Cannot open $!";
    open( IFAL, "$gvfaldir/$base.lab" )           || die "Cannot open $!";
    open( OFAL, ">$mspffaldir/$base.lab" )        || die "Cannot open $!";

    while ( ( $istr = <IFAL> ) && ( $lstr = <LAB> ) ) {
      chomp($istr);
      chomp($lstr);
      @iarr = split( / /, $istr );
      @larr = split( / /, $lstr );
      print OFAL "$iarr[0] $iarr[1] $larr[$#larr]\n";
    }

    close(LAB);
    close(IFAL);
    close(OFAL);
    print OSCP "$mspffaldir/$base.lab\n";
  }

  close(ISCP);
  close(OSCP);
}

# sub routine for calculating statistics of modulation spectrum
sub make_mspf($) {
  my ($gentype) = @_;
  my ( $cmp, $base, $type, $mspftype, $orgdir, $line, $d );
  my ( $str, @arr, $start, $end, $find, $j );

  # reset modulation spectrum files
  foreach $type ('mgc') {
    foreach $mspftype ( 'nat', $gentype ) {
      for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
        shell("rm -f $mspfstatsdir{$mspftype}/${type}_dim$d.data");
        shell("touch $mspfstatsdir{$mspftype}/${type}_dim$d.data");
      }
    }
  }

  # calculate modulation spectrum from natural/generated sequences
  open( SCP, "$scp{'trn'}" ) || die "Cannot open $!";
  while (<SCP>) {
    $cmp = $_;
    chomp($cmp);
    $base = `basename $cmp .cmp`;
    chomp($base);
    print " Making data from $base.lab for modulation spectrum...";

    foreach $type ('mgc') {
      foreach $mspftype ( 'nat', $gentype ) {

        # determine original feature directory
        if   ( $mspftype eq 'nat' ) { $orgdir = "$datdir/$type"; }
        else                        { $orgdir = "$mspfdir/$mspftype"; }

        # subtract utterance-level mean
        $line = get_cmd_utmean( "$orgdir/$base.$type", $type );
        shell("$line > $mspfdatdir{$mspftype}/$base.$type.mean");
        $line = get_cmd_vopr( "$orgdir/$base.$type", "-s", "$mspfdatdir{$mspftype}/$base.$type.mean", $type );
        shell("$line > $mspfdatdir{$mspftype}/$base.$type.subtracted");

        # extract non-silence frames
        if ( @slnt > 0 ) {
          shell("rm -f $mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil");
          shell("touch $mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil");
          open( F, "$gvfaldir/$base.lab" ) || die "Cannot open $!";
          while ( $str = <F> ) {
            chomp($str);
            @arr = split( / /, $str );
            $find = 0;
            for ( $j = 0 ; $j < @slnt ; $j++ ) {
              if ( $arr[2] eq "$slnt[$j]" ) { $find = 1; last; }
            }
            if ( $find == 0 ) {
              $start = int( $arr[0] * ( 1.0e-7 / ( $fs / $sr ) ) );
              $end   = int( $arr[1] * ( 1.0e-7 / ( $fs / $sr ) ) );
              shell("$BCUT -s $start -e $end -l $ordr{$type} < $mspfdatdir{$mspftype}/$base.$type.subtracted >> $mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil");
            }
          }
          close(F);
        }
        else {
          shell("cp $mspfdatdir{$mspftype}/$base.$type.subtracted $mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil");
        }

        # calculate modulation spectrum of each dimension
        for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
          $line = get_cmd_seq2ms( "$mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil", $type, $d );
          shell("$line >> $mspfstatsdir{$mspftype}/${type}_dim$d.data");
        }

        # remove temporal files
        shell("rm -f $mspfdatdir{$mspftype}/$base.$type.mean");
        shell("rm -f $mspfdatdir{$mspftype}/$base.$type.subtracted.no-sil");
      }
    }
    print "done\n";
  }
  close(SCP);

  # estimate modulation spectrum statistics
  foreach $type ('mgc') {
    foreach $mspftype ( 'nat', $gentype ) {
      for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
        shell( "$VSTAT -o 1 -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $mspfstatsdir{$mspftype}/${type}_dim$d.data > $mspfmean{$type}{$mspftype}[$d]" );
        shell( "$VSTAT -o 2 -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $mspfstatsdir{$mspftype}/${type}_dim$d.data | $SOPR -SQRT > $mspfstdd{$type}{$mspftype}[$d]" );

        # remove temporal files
        shell("rm -f $mspfstatsdir{$mspftype}/${type}_dim$d.data");
      }
    }
  }
}

##################################################################################################

# add by wwy74 : follow all
# wait the jobs
sub wait_jobs {
  my @jobs = @_;
  my $sec_use = 0;
  return $sec_use if (scalar(@jobs) <= 0);

  my @left = ();
  my $ts = 60;
  my $ins= 30;

  _loop:
  my @arr = ();
  if($slurm_qsub){
    @arr = `squeue`;
  }else{
    @arr = `qstat -u '*'`;
  }
  my @all = ();
  foreach ( @arr ) {
    push @all, $1 if ( /^\s*(\d+)/ );
  }

  @left = ();
  foreach $jid ( @jobs ) {
    my $k = 0;
    for ($k=0; $k<=$#all; $k++ ) {
      last if ( $jid eq $all[$k] );
    }
    push @left,$jid if ( $k<scalar(@all) );
  }
  return $sec_use if ( scalar(@left) <= 0 );
  @jobs=@left;
  $ins =  30 if ( $ts <= 0 );
  print "sleep $ts: @jobs\n";
  sleep $ts; $sec_use += $ts; $ts += $ins;
  $ins = -30 if ( $ts >= 60*5 );
  goto _loop;
}
sub split_scp {
  my $file = shift;
  my $cnt  = shift; $cnt=10 if(!defined $cnt);
  my $name = shift; $name='tmp' if(!defined $name);

  my @fn = ();
  my $path = "$datdir/scp/" .$name;
  shell("mkdir -p $path");
  for (my $i=0; $i<$cnt; $i++ ) {
    $fn[$i] = $path ."/$i";
    open $out[$i],">$fn[$i]";
  }
  open SCP,"$file";
  @arr = <SCP>;
  close SCP;

  for (my $i=0; $i<scalar(@arr); $i++ ) {
    $h = $out[$i%$cnt];
    print $h "$arr[$i]";
  }
  for(my $i = 0; $i < $cnt; $i ++){
    close $out[$i];
  }
  return @fn;
}
sub load_mlf {
  my $file = shift;

  open MLF, $file or die "$!\n";
  my ($mlf,$cont);
  while ( my $line = <MLF> ) {
    chomp $line;
    $line =~ s/^\s+//; $line =~ s/\s+$//;
    if ( $line =~ /MLF/ ) {
      next;
    }
    elsif ( $line =~ /\.lab\"/ ) {
      $line =~ s/\"//g;   # del "
      $line = `basename $line`; chomp($line);
      $line =~ s/\.lab$//;
      $cont = [];
      $mlf->{$line} = $cont;
    }
    elsif ( $line =~ /^\.$/ ) {
      $cont = undef;
    }
    else {
      push @$cont, $line if($line ne "");
    }
  }
  close MLF;
  return $mlf;
}
sub save_mlf {
  my $mlf  = shift;
  my $file = shift;

  open MLF, ">$file" or die "$file: $!\n";
  print MLF "#!MLF!#\n";
  foreach $id ( sort keys %$mlf ) {
    print MLF "\"*/$id.lab\"\n";
    $cont = $mlf->{$id};
    for (my $i=0; $i<scalar(@$cont); $i++ ) {
      print MLF "$cont->[$i]\n";
    }
    print MLF ".\n";
  }
  close MLF;
}
sub add_labfile {
  my $mlf  = shift;
  my $file = shift;

  $id = `basename $file`; chomp($id);
  $id =~ s/\.lab$//;

  open TF, "$file" or die "$file : $!\n";
  my @cont = <TF>;
  chomp @cont;
  close TF;

  $mlf->{$id} = \@cont;
}

sub read_cmpfn{
  my $cmpfn = shift;
  my $beg   = shift;
  my $end   = shift;

  open IN,$cmpfn or die "read_cmpfn : can not open file : $cmpfn\n";
  my @STAT = stat(IN);
  my $data;
  read IN, $data, $STAT[7];
  close IN;

  my $nframe     = unpack "l1",    $data;
  my $frameshift = unpack "x4l1",  $data;
  my $byte       = unpack "x8s1",  $data;
  my $type       = unpack "x10s1", $data;

  my $n = $nframe * $byte + 12;
  die "read_cmpfn: $cmpfn : $n > $STAT[7]\n" if($n > $STAT[7]);
  my $fn=$byte / 4; # float number of each frame

  $n = $fn * $nframe;
  my @data       = unpack "x12f$n",$data;
  # 自动甄别$beg/$end是时间还是帧数
  if(!defined $beg || $beg < 0){
    $beg = 0;
  }elsif($beg >= $frameshift && $beg % $frameshift == 0){
    $beg = $beg;
  }else{
    $beg = $beg * $frameshift;
  }
  if(!defined $end || $end < 0){
    $end = $nframe*$frameshift;
  }elsif($end >= $frameshift && $end % $frameshift == 0){
    $end = $end;
  }else{
    $end = $end * $frameshift;
  }
  my ($nbeg,$nend) = (int($beg/$frameshift),int($end/$frameshift));
  die "" if($nbeg < 0 || $nend > $nframe);

  my @dpf; # data per frame
  for(my $i = $nbeg; $i < $nend; $i ++){
    my $base = $i * $fn;
    for(my $j = 0; $j < $fn; $j ++){
      $dpf[$i-$nbeg][$j] = $data[$base+$j];
    }
  }
  return \@dpf;
}

sub streaming_frame{
  my $dpf    = shift;
  my @stream = @_;

  # check sth
  my $ssize = 0; map{ $ssize += $_; } @stream;
  for(my $i = 1; $i < scalar @$dpf; $i ++){
    my $s = scalar(@{$dpf->[$i]});
    if($ssize > $s){
      die "streaming_frame : the size of $i-th frame of data is $s, which is not equal to $ssize(=", join "+",@stream, ")!";
    }
    my $s1= scalar(@{$dpf->[$i-1]});
    if($s != $s1){
      die "streaming_frame : the size of $i-th frame of data is $s, which is not equal to previous $s1 !";
    }
  }
  # streaming
  my @dps;
  for(my $i = 0; $i < scalar @$dpf; $i ++){
    my $base = 0;
    for(my $ns = 0; $ns <= $#stream; $ns ++){
      for(my $j = 0; $j < $stream[$ns]; $j ++){
        $dps[$ns][$i][$j] = $dpf->[$i][$base+$j];
      }
      $base += $stream[$ns];
    }
  }
  return @dps;
}

# added by zhx66 
sub simple_get_partition{
  my $iter_cnt = shift;
  my @partition_names=("limitcpu","fatq","cpuq/sjtu");
  if($iter_cnt<= 80){
    return $partition_names[0];
  }
  elsif($iter_cnt <= 100){
    return $partition_names[1];
  }
  else{
    return $partition_names[2];
  }
}
sub my_split_scp {
  my $file = shift;
  my $cnt  = shift; $cnt=-1 if(!defined $cnt);
  my $name = shift; $name='tmp' if(!defined $name);

  my @fn = ();
  my $path = "$datdir/scp/" .$name;
  shell("mkdir -p $path");
  for (my $i=0; $i<$cnt; $i++ ) {
    $fn[$i] = $path ."/$i";
    open $out[$i],">$fn[$i]";
  }
  open SCP,"$file";
  @arr = <SCP>;
  close SCP;

  for (my $i=0; $i<$cnt; $i++ ) {
    my $len_per_file = scalar(@arr) / $cnt;
    for (my $j=$i*$len_per_file; $j < ($i+1)*$len_per_file; $j++){
      $h = $out[$i];
      print $h "$arr[$j]";
    }
    close $out[$i];
  }
  return @fn;
}

1;


