#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(gettimeofday);

require "epn-options.pm";
require "ribo.pm";

my $ribodir = $ENV{'RIBODIR'};
if(! exists($ENV{'RIBODIR'})) { 
  printf STDERR ("\nERROR, the environment variable RIBODIR is not set, please set it to the directory where you installed the ribotyper scripts and their dependencies.\n"); 
  exit(1); 
}
if(! (-d $ribodir)) { 
  printf STDERR ("\nERROR, the ribotyper directory specified by your environment variable RIBODIR does not exist.\n"); 
  exit(1); 
}    
my $ribo_exec_dir  = $ribodir . "/";
my $esl_exec_dir   = $ribodir . "/infernal-1.1.2/easel/miniapps/";
my $ribo_model_dir = $ribodir . "/models/";

#########################################################
# Command line and option processing using epn-options.pm
#
# opt_HH: 2D hash:
#         1D key: option name (e.g. "-h")
#         2D key: string denoting type of information 
#                 (one of "type", "default", "group", "requires", "incompatible", "preamble", "help")
#         value:  string explaining 2D key:
#                 "type":         "boolean", "string", "integer" or "real"
#                 "default":      default value for option
#                 "group":        integer denoting group number this option belongs to
#                 "requires":     string of 0 or more other options this option requires to work, each separated by a ','
#                 "incompatible": string of 0 or more other options this option is incompatible with, each separated by a ','
#                 "preamble":     string describing option for preamble section (beginning of output from script)
#                 "help":         string describing option for help section (printed if -h used)
#                 "setby":        '1' if option set by user, else 'undef'
#                 "value":        value for option, can be undef if default is undef
#
# opt_order_A: array of options in the order they should be processed
# 
# opt_group_desc_H: key: group number (integer), value: description of group for help output
my %opt_HH = ();      
my @opt_order_A = (); 
my %opt_group_desc_H = ();

# Add all options to %opt_HH and @opt_order_A.
# This section needs to be kept in sync (manually) with the &GetOptions call below
$opt_group_desc_H{"1"} = "basic options";
#     option            type       default               group   requires incompat    preamble-output                                   help-output    
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,      undef,                                            "display this help",                                  \%opt_HH, \@opt_order_A);
opt_Add("-f",           "boolean", 0,                        1,    undef, undef,      "forcing directory overwrite",                    "force; if <output directory> exists, overwrite it",  \%opt_HH, \@opt_order_A);
opt_Add("-v",           "boolean", 0,                        1,    undef, undef,      "be verbose",                                     "be verbose; output commands to stdout as they're run", \%opt_HH, \@opt_order_A);
opt_Add("-n",           "integer", 0,                        1,    undef, undef,      "use <n> CPUs",                                   "use <n> CPUs", \%opt_HH, \@opt_order_A);
opt_Add("--keep",       "boolean", 0,                        1,    undef, undef,      "keep all intermediate files",                    "keep all intermediate files that are removed by default", \%opt_HH, \@opt_order_A);
$opt_group_desc_H{"2"} = "16S-sensor related options";
opt_Add("--Sminlen",    "integer", 100,                      2,    undef, undef,      "set 16S-sensor minimum seq length to <n>",                    "set 16S-sensor minimum sequence length to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Smaxlen",    "integer", 2000,                     2,    undef, undef,      "set 16S-sensor maximum seq length to <n>",                    "set 16S-sensor minimum sequence length to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Smaxevalue",    "real", 1e-40,                    2,    undef, undef,      "set 16S-sensor maximum E-value to <x>",                       "set 16S-sensor maximum E-value to <x>", \%opt_HH, \@opt_order_A);
opt_Add("--Sminid1",    "integer", 75,                       2,    undef, undef,      "set 16S-sensor min percent id for seqs <= 350 nt to <n>",     "set 16S-sensor minimum percent id for seqs <= 350 nt to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Sminid2",    "integer", 80,                       2,    undef, undef,      "set 16S-sensor min percent id for seqs [351..600] nt to <n>", "set 16S-sensor minimum percent id for seqs [351..600] nt to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Sminid3",    "integer", 86,                       2,    undef, undef,      "set 16S-sensor min percent id for seqs > 600 nt to <n>",      "set 16S-sensor minimum percent id for seqs > 600 nt to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Smincovall", "integer", 10,                       2,    undef, undef,      "set 16S-sensor min coverage for all sequences to <n>",        "set 16S-sensor minimum coverage for all sequences to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Smincov1",   "integer", 10,                       2,    undef, undef,      "set 16S-sensor min coverage for seqs <= 350 nt to <n>",       "set 16S-sensor minimum coverage for seqs <= 350 nt to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--Smincov2",   "integer", 10,                       2,    undef, undef,      "set 16S-sensor min coverage for seqs  > 350 nt to <n>",       "set 16S-sensor minimum coverage for seqs  > 350 nt to <n>", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $usage    = "Usage: ribosensor-wrapper.pl [-options] <fasta file to annotate> <output directory>\n";
$usage      .= "\n";
my $synopsis = "ribosensor-wrapper.pl :: analyze ribosomal RNA sequences with profile HMMs and BLASTN";
my $options_okay = 
    &GetOptions('h'            => \$GetOptions_H{"-h"}, 
                'f'            => \$GetOptions_H{"-f"},
                'v'            => \$GetOptions_H{"-v"},
                'n=s'          => \$GetOptions_H{"-n"},
                'keep'         => \$GetOptions_H{"--keep"}, 
                'Sminlen=s'    => \$GetOptions_H{"--Sminlen"}, 
                'Smaxlen=s'    => \$GetOptions_H{"--Smaxlen"}, 
                'Smaxevalue=s' => \$GetOptions_H{"--Smaxevalue"}, 
                'Sminid1=s'    => \$GetOptions_H{"--Sminid1"}, 
                'Sminid2=s'    => \$GetOptions_H{"--Sminid2"}, 
                'Sminid3=s'    => \$GetOptions_H{"--Sminid3"},
                'Smincovall=s' => \$GetOptions_H{"--Smincovall"},
                'Smincov1=s'   => \$GetOptions_H{"--Smincov1"},
                'Smincov2=s'   => \$GetOptions_H{"--Smincov2"});

my $total_seconds = -1 * ribo_SecondsSinceEpoch(); # by multiplying by -1, we can just add another ribo_SecondsSinceEpoch call at end to get total time
my $executable    = $0;
my $date          = scalar localtime();
my $version       = "0.01";
my $version_str   = "0p01";
my $releasedate   = "May 2017";

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

# print help and exit if necessary
if((! $options_okay) || ($GetOptions_H{"-h"})) { 
  riboOutputBanner(*STDOUT, $version, $releasedate, $synopsis, $date);
  opt_OutputHelp(*STDOUT, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if(! $options_okay) { die "ERROR, unrecognized option;"; }
  else                { exit 0; } # -h, exit with 0 status
}

# check that number of command line args is correct
if(scalar(@ARGV) != 2) {   
  print "Incorrect number of command line arguments.\n";
  print $usage;
  print "\nTo see more help on available options, do dnaorg_annotate.pl -h\n\n";
  exit(1);
}
my ($seq_file, $dir_out) = (@ARGV);

# set options in opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

my $cmd  = undef;                    # a command to be run by ribo_RunCommand()
my $ncpu = opt_Get("-n" , \%opt_HH); # number of CPUs to use with search command (default 0: --cpu 0)
my @to_remove_A = (); # array of files to remove at end

# if $dir_out already exists remove it only if -f also used
if(-d $dir_out) { 
  $cmd = "rm -rf $dir_out";
  if(opt_Get("-f", \%opt_HH)) { ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH)); }
  else                        { die "ERROR directory named $dir_out already exists. Remove it, or use -f to overwrite it."; }
}
elsif(-e $dir_out) { 
  $cmd = "rm $dir_out";
  if(opt_Get("-f", \%opt_HH)) { ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH)); }
  else                        { die "ERROR a file named $dir_out already exists. Remove it, or use -f to overwrite it."; }
}
# if $dir_out does not exist, create it
if(! -d $dir_out) { 
  $cmd = "mkdir $dir_out";
  ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH));
}

my $dir_out_tail = $dir_out;
$dir_out_tail    =~ s/^.+\///; # remove all but last dir
my $out_root     = $dir_out .   "/" . $dir_out_tail   . ".ribosensor";

#############################################
# output program banner and open output files
#############################################
# output preamble
my @arg_desc_A = ();
my @arg_A      = ();

push(@arg_desc_A, "target sequence input file");
push(@arg_A, $seq_file);

push(@arg_desc_A, "output directory name");
push(@arg_A, $dir_out);

ribo_OutputBanner(*STDOUT, $version, $releasedate, $synopsis, $date);
opt_OutputPreamble(*STDOUT, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# make sure we have the sensor executable files in the current directory
my %execs_H = (); # hash with paths to all required executables
$execs_H{"sensor"}                = "./16S_sensor_script";
$execs_H{"sensor-partition"}      = "./partition_by_length_v2.pl";
$execs_H{"sensor-classification"} = "./classification_v3.pl";
$execs_H{"esl-seqstat"}           = $esl_exec_dir   . "esl-seqstat";
$execs_H{"esl-sfetch"}            = $esl_exec_dir   . "esl-sfetch";
$execs_H{"ribo"}                  = $ribo_exec_dir  . "ribotyper.pl";
ribo_ValidateExecutableHash(\%execs_H);

###################################################################
# Step 1: Split up input sequence file into 3 files based on length
###################################################################
# we do this before running ribotyper, even though ribotyper is run
# on the full file so that we'll exit if we have a problem in the
# sequence file
my $progress_w = 52; # the width of the left hand column in our progress output, hard-coded
my $start_secs = ribo_OutputProgressPrior("Partitioning sequence file based on sequence lengths", $progress_w, undef, *STDOUT);
my %seqidx_H = (); # key: sequence name, value: index of sequence in original input sequence file (1..$nseq)
my %seqlen_H = (); # key: sequence name, value: length of sequence
my %width_H  = (); # hash, key is "model" or "target", value is maximum length of any model/target

# check for SSI index file for the sequence file,
# if it doesn't exist, create it
my $ssi_file = $seq_file . ".ssi";
if(ribo_CheckIfFileExistsAndIsNonEmpty($ssi_file, undef, undef, 0) != 1) { 
  ribo_RunCommand($execs_H{"esl-sfetch"} . " --index $seq_file > /dev/null", opt_Get("-v", \%opt_HH));
  if(ribo_CheckIfFileExistsAndIsNonEmpty($ssi_file, undef, undef, 0) != 1) { 
    die "ERROR, tried to create $ssi_file, but failed"; 
  }
}

my $seqstat_file = $out_root . ".seqstat";
if(! opt_Get("--keep", \%opt_HH)) { 
  push(@to_remove_A, $seqstat_file);
}
ribo_ProcessSequenceFile($execs_H{"esl-seqstat"}, $seq_file, $seqstat_file, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH);

# create new files for the 3 sequence length ranges:
my $nseq_parts     = 3;               # hard-coded, number of sequence partitions based on length
my @spart_minlen_A = (0,   351, 601); # hard-coded, minimum length for each sequence partition
my @spart_maxlen_A = (350, 600, -1);  # hard-coded, maximum length for each sequence partition, -1 == infinity
my @spart_desc_A   = ("0..350", "351..600", "601..inf");

my $ncov_parts     = 2;               # hard-coded, number of coverage threshold partitions based on length
my @cpart_minlen_A = (0,   351);      # hard-coded, minimum length for each coverage threshold partition
my @cpart_maxlen_A = (350, -1);       # hard-coded, maximum length for each coverage threshold partition, -1 == infinity

my @subseq_file_A   = (); # array of fasta files that we fetch into
my @subseq_sfetch_A = (); # array of sfetch input files that we created
my @subseq_nseq_A   = (); # array of number of sequences in each sequence

for(my $i = 0; $i < $nseq_parts; $i++) { 
  $subseq_sfetch_A[$i] = $out_root . "." . ($i+1) . ".sfetch";
  $subseq_file_A[$i]   = $out_root . "." . ($i+1) . ".fa";
  $subseq_nseq_A[$i]   = fetch_seqs_in_length_range($execs_H{"esl-sfetch"}, $seq_file, $spart_minlen_A[$i], $spart_maxlen_A[$i], \%seqlen_H, $subseq_sfetch_A[$i], $subseq_file_A[$i], \%opt_HH);
  if((! opt_Get("--keep", \%opt_HH)) && ($subseq_nseq_A[$i] > 0)) { 
    push(@to_remove_A, $subseq_sfetch_A[$i]);
    push(@to_remove_A, $subseq_file_A[$i]);
  }
}
ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);

#############################################
# Step 2: Run ribotyper on full sequence file
#############################################
# It's important we run ribotyper only once on full file so that E-values are accurate. 
$start_secs = ribo_OutputProgressPrior("Running ribotyper on full sequence file", $progress_w, undef, *STDOUT);
my $ribo_dir_out    = $dir_out . "/ribo-out";
my $ribo_stdoutfile = $out_root . ".ribotyper.stdout";
my $ribotyper_cmd   = $execs_H{"ribo"} . " -f -n $ncpu --inaccept $ribo_model_dir/ssu.arc.bac.accept --scfail --covfail $seq_file $ribo_dir_out > $ribo_stdoutfile";
ribo_RunCommand($ribotyper_cmd, opt_Get("-v", \%opt_HH));
ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);

###########################################################################
# Step 3: Run 16S-sensor on the (up to 3) length-partitioned sequence files
###########################################################################
my @sensor_dir_out_A             = (); # [0..$i..$nseq_parts-1], directory created for sensor run on partition $i
my @sensor_stdoutfile_A          = (); # [0..$i..$nseq_parts-1], standard output file for sensor run on partition $i
my @sensor_classfile_argument_A  = (); # [0..$i..$nseq_parts-1], sensor script argument for classification output file for partition $i
my @sensor_classfile_fullpath_A  = (); # [0..$i..$nseq_parts-1], full path to classification output file name for partition $i
my @sensor_minid_A               = (); # [0..$i..$nseq_parts-1], minimum identity percentage threshold to use for round $i
my $sensor_cmd = undef;                # command used to run sensor

my $sensor_minlen    = opt_Get("--Sminlen",    \%opt_HH);
my $sensor_maxlen    = opt_Get("--Smaxlen",    \%opt_HH);
my $sensor_maxevalue = opt_Get("--Smaxevalue", \%opt_HH);

for(my $i = 0; $i < $nseq_parts; $i++) { 
  $sensor_minid_A[$i] = opt_Get("--Sminid" . ($i+1), \%opt_HH);
  if($subseq_nseq_A[$i] > 0) { 
    $start_secs = ribo_OutputProgressPrior("Running 16S-sensor on seqs of length $spart_desc_A[$i]", $progress_w, undef, *STDOUT);
    $sensor_dir_out_A[$i]             = $dir_out . "/sensor-" . ($i+1) . "-out";
    $sensor_stdoutfile_A[$i]          = $out_root . "sensor-" . ($i+1) . ".stdout";
    $sensor_classfile_argument_A[$i]  = "sensor-class." . ($i+1) . ".out";
    $sensor_classfile_fullpath_A[$i]  = $sensor_dir_out_A[$i] . "/sensor-class." . ($i+1) . ".out";
    $sensor_cmd = $execs_H{"sensor"} . " $sensor_minlen $sensor_maxlen $subseq_file_A[$i] $sensor_classfile_argument_A[$i] $sensor_minid_A[$i] $sensor_maxevalue $sensor_dir_out_A[$i] > $sensor_stdoutfile_A[$i]";
    ribo_RunCommand($sensor_cmd, opt_Get("-v", \%opt_HH));
    ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);
  }
  else { 
    $sensor_dir_out_A[$i]            = undef;
    $sensor_stdoutfile_A[$i]         = undef;
    $sensor_classfile_fullpath_A[$i] = undef;
    $sensor_classfile_argument_A[$i] = undef;
  }
}

###########################################################################
# Step 4: Parse 16S-sensor results and create intermediate file 
###########################################################################
# parse 16S-sensor file to create intermediate file in the same format
# as the ribotyper short output format, first unsorted, then sort it.
my $unsrt_sensor_shortfile = $out_root . ".short.sensor.unsrt"; # unsorted 'short' format sensor output
my $sensor_shortfile       = $out_root . ".short.sensor";       # sorted 'short' format sensor output
parse_sensor_files($sensor_shortfile, \@sensor_classfile_fullpath_A, \@cpart_minlen_A, \@cpart_maxlen_A, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH);

# sort sensor shortfile
# maybe write function that makes ribotyper short file just like the sensor short file first? 
# write function that takes in ribotyper short file and sensor short file and combines them

#####################################################################
# SUBROUTINES 
#####################################################################

#################################################################
# Subroutine : fetch_seqs_in_length_range()
# Incept:      EPN, Fri May 12 11:13:46 2017
#
# Purpose:     Use esl-sfetch to fetch sequences in a given length
#              range from <$seq_file> given the lengths in %{$seqlen_HR}.
#
# Arguments: 
#   $sfetch_exec:  path to esl-sfetch executable
#   $seq_file:     sequence file to process
#   $minlen:       minimum length sequence to fetch
#   $maxlen:       maximum length sequence to fetch (-1 for infinity)
#   $seqlen_HR:    ref to hash of sequence lengths to fill here
#   $sfetch_file:  name of esl-sfetch input file to create
#   $subseq_file:  name of fasta file to create 
#   $opt_HHR:      reference to 2D hash of cmdline options
# 
# Returns:     Number of sequences fetched.
#
# Dies:        If the esl-sfetch command fails.
#
################################################################# 
sub fetch_seqs_in_length_range { 
  my $nargs_expected = 8;
  my $sub_name = "fetch_seqs_in_length_range";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($sfetch_exec, $seq_file, $minlen, $maxlen, $seqlen_HR, $sfetch_file, $subseq_file, $opt_HHR) = (@_);

  my $target;   # name of a target sequence
  my $nseq = 0; # number of sequences fetched

  open(SFETCH, ">", $sfetch_file) || die "ERROR unable to open $sfetch_file for writing";

  foreach $target (keys %{$seqlen_HR}) { 
    if(! exists $seqlen_HR->{$target}) { 
      die "ERROR in $sub_name, no length data for $target"; 
    }
    if(($seqlen_HR->{$target} >= $minlen) && 
       (($maxlen == -1) || ($seqlen_HR->{$target} <= $maxlen))) {  
      print SFETCH $target . "\n";
      $nseq++;
    }
  }
  close(SFETCH);

  if($nseq > 0) { 
    my $sfetch_cmd = $sfetch_exec . " -f $seq_file $sfetch_file > $subseq_file"; 
    ribo_RunCommand($sfetch_cmd, opt_Get("-v", $opt_HHR));
  }

  return $nseq;
}

#################################################################
# Subroutine : parse_sensor_files()
# Incept:      EPN, Fri May 12 16:33:57 2017
#
# Purpose:     For each sequence in a set of sensor 'classification'
#              output files, output a single summary line to a new file.
#
# Arguments: 
#   $shortfile:    name of file to create 
#   $classfile_AR: ref to array with names of sensor class files
#   $minlen_AR:    ref to array of minimum lengths for coverage threshold partitions 
#   $maxlen_AR:    ref to array of maximum lengths for coverage threshold partitions 
#   $seqidx_HR:    ref to hash of sequence indices
#   $seqlen_HR:    ref to hash of sequence lengths
#   $width_HR:     ref to hash with max lengths of sequence index and target
#   $opt_HHR:      reference to 2D hash of cmdline options
# 
# Returns:     Number of sequences fetched.
#
# Dies:        If the esl-sfetch command fails.
#
################################################################# 
sub parse_sensor_files { 
  my $nargs_expected = 8;
  my $sub_name = "parse_sensor_files";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($short_file, $classfile_AR, $minlen_AR, $maxlen_AR, $seqidx_HR, $seqlen_HR, $width_HR, $opt_HHR) = (@_);

  my $nclassfiles = scalar(@{$classfile_AR});
  my $line   = undef; # a line of input
  my $seqid  = undef; # name of a sequence
  my $class  = undef; # class of a sequence
  my $strand = undef; # strand of a sequence
  my $nhits  = undef; # number of hits to a sequence
  my $cov    = undef; # coverage of a sequence;
  my @el_A   = ();    # array of elements on a line
  my $passfail = undef; # PASS or FAIL for a sequence
  my $failmsg  = undef; # list of errors for the sequence
  my $i;                # a counter

  # get the coverage thresholds for each coverage threshold partition
  my $ncov_parts  = scalar(@{$minlen_AR});
  my $cthresh_all = opt_Get("--Smincovall", $opt_HHR);
  my @cthresh_part_A = ();
  my $cov_part = undef; # the coverage partition a sequence belongs to (index in $cthresh_part_)
  for($i = 0; $i < $ncov_parts; $i++) { 
    $cthresh_part_A[$i] = opt_Get("--Smincov" . ($i+1), $opt_HHR);
  }

  open(OUT, ">", $short_file) || die "ERROR in $sub_name, unable to open $short_file for writing";

  foreach my $classfile (@{$classfile_AR}) { 
    if(defined $classfile) { 
      open(IN, $classfile) || die "ERROR unable to open $classfile for reading in $sub_name"; 
      while($line = <IN>) { 
        # example lines:
        #ALK.1_567808	imperfect_match	minus	1	38
        #T12A.3_40999	imperfect_match	minus	1	41
        #T13A.1_183523	imperfect_match	minus	1	41
        chomp $line;

        my @el_A = split(/\t/, $line);
        if(scalar(@el_A) != 5) { die "ERROR unable to parse sensor output file line: $line"; }
        ($seqid, $class, $strand, $nhits, $cov) = (@el_A);
        $passfail = "PASS";
        $failmsg = "";

        # sanity check
        if((! exists $seqidx_HR->{$seqid}) || (! exists $seqlen_HR->{$seqid})) { 
          die "ERROR in $sub_name, found unexpected sequence $seqid\n";
        }

        if($class eq "too long") { 
          $passfail = "FAIL";
          $failmsg .= "sensor_toolong;"; # TODO: add to analysis document
        }
        elsif($class eq "too short") { 
          $passfail = "FAIL";
          $failmsg .= "sensor_tooshort;"; # TODO: add to analysis document
        }
        elsif($class eq "no") { 
          $passfail = "FAIL";
          $failmsg .= "sensor_no;"; # TODO: add to analysis document
        }
        elsif($class eq "yes") { 
          $passfail = "PASS";
        }
        #elsif($class eq "partial") { 
        # I think sensor no longer can output this
        #}
        elsif($class eq "imperfect_match") { 
          $passfail = "FAIL";
          $failmsg  .= "sensor_imperfect_match;";
        }
        elsif($strand eq "mixed") { 
          $passfail = "FAIL";
          $failmsg  .= "sensor_misassembly;";
        }
        elsif($nhits > 1) { 
          $passfail = "FAIL";
          $failmsg  .= "sensor_HSPproblem;";
        }
        # now stop the else, because remainder don't depend on class
        if($cov ne "NA") { 
          $cov_part = determine_coverage_threshold($seqlen_HR->{$seqid}, $minlen_AR, $maxlen_AR, $ncov_parts);
          if($cov < $cthresh_all) { 
            $passfail = "FAIL";
            $failmsg  .= "sensor_nosimilarity;"; 
            # TODO put this in table 1 in analysis doc, in table 3 but not table 1
          }
          elsif($cov < $cthresh_part_A[$cov_part]) { 
            $passfail = "FAIL";
            $failmsg  .= "sensor_lowsimilarity;";
          }
        }
        if($failmsg eq "") { $failmsg = "-"; }
        printf OUT ("%*d  %-*s  %4s  %s\n", $width_HR->{"index"}, $seqidx_HR->{$seqid}, $width_HR->{"target"}, $seqid, $passfail, $failmsg);
      }
    }
  }
  close(OUT);
  return;
}


#################################################################
# Subroutine : determine_coverage_threshold()
# Incept:      EPN, Fri May 12 17:02:43 2017
#
# Purpose:     Given a sequence length and arrays of min and max values
#              in arrays, determine what index of the array the length
#              falls in between the min and max of.
#
# Arguments: 
#   $length:    length of the sequence
#   $min_AR:    ref to array of minimum lengths for coverage threshold partitions 
#   $max_AR:    ref to array of maximum lengths for coverage threshold partitions 
#   $n:         size of the arrays
# 
# Returns:     Index (0..n-1).
#
# Dies:        If $length is outside the range
#
################################################################# 
sub determine_coverage_threshold { 
  my $nargs_expected = 4;
  my $sub_name = "determine_coverage_threshold";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($length, $min_AR, $max_AR, $n) = (@_);

  my $i; # counter

  for($i = 0; $i < $n; $i++) {
    if($length < $min_AR->[$i]) { die "ERROR in $sub_name, length $length out of bounds (too short)"; }
    if(($max_AR->[$i] == -1) || ($length >= $max_AR->[$i])) { 
      return $i;
    }
  }
  die "ERROR in $sub_name, length $length out of bounds (too long)"; 

  return 0; # never reached
}

