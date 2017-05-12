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
my $ribo_exec_dir = $ribodir . "/";
my $esl_exec_dir  = $ribodir . "/infernal-1.1.2/easel/miniapps/";
my $df_model_dir  = $ribodir . "/models/";

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
                'Sminid3=s'    => \$GetOptions_H{"--Sminid3"}); 

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
my $nparts = 3;                 # hard-coded, number of partitions
my @part_minlen_A = (0,   351, 601); # hard-coded, minimum length for each partition
my @part_maxlen_A = (350, 600, -1);  # hard-coded, maximum length for each partition, -1 == infinity
my @part_desc_A   = ("0..350", "351..600", "601..inf");

my @subseq_file_A   = (); # array of fasta files that we fetch into
my @subseq_sfetch_A = (); # array of sfetch input files that we created
my @subseq_nseq_A   = (); # array of number of sequences in each sequence

for(my $i = 0; $i < $nparts; $i++) { 
  $subseq_sfetch_A[$i] = $out_root . "." . ($i+1) . ".sfetch";
  $subseq_file_A[$i]   = $out_root . "." . ($i+1) . ".fa";
  $subseq_nseq_A[$i]   = fetch_seqs_in_length_range($execs_H{"esl-sfetch"}, $seq_file, $part_minlen_A[$i], $part_maxlen_A[$i], \%seqlen_H, $subseq_sfetch_A[$i], $subseq_file_A[$i], \%opt_HH);
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
my $ribotyper_cmd   = $execs_H{"ribo"} . " -f -n $ncpu $seq_file $ribo_dir_out > $ribo_stdoutfile";
ribo_RunCommand($ribotyper_cmd, opt_Get("-v", \%opt_HH));
ribo_OutputProgressComplete($start_secs, "output saved to $ribo_stdoutfile", undef, *STDOUT);

################################################################
# Step 3: Run 16S-sensor the length-partitioned 3 sequence files
################################################################
my @sensor_dir_out_A    = (); # [0..$i..$nparts-1], directory created for sensor run on partition $i
my @sensor_stdoutfile_A = (); # [0..$i..$nparts-1], standard output file for sensor run on partition $i
my @sensor_classfile_A  = (); # [0..$i..$nparts-1], classification output file name for sensor run on partition $i
my @sensor_minid_A      = (); # [0..$i..$nparts-1], minimum identity percentage threshold to use for round $i
my $sensor_cmd = undef;       # command used to run sensor

my $sensor_minlen    = opt_Get("--Sminlen",    \%opt_HH);
my $sensor_maxlen    = opt_Get("--Smaxlen",    \%opt_HH);
my $sensor_maxevalue = opt_Get("--Smaxevalue", \%opt_HH);

for(my $i = 0; $i < $nparts; $i++) { 
  $sensor_minid_A[$i] = opt_Get("--Sminid" . ($i+1), \%opt_HH);
  if($subseq_nseq_A[$i] > 0) { 
    $start_secs = ribo_OutputProgressPrior("Running 16S-sensor on seqs of length $part_desc_A[$i]", $progress_w, undef, *STDOUT);
    $sensor_dir_out_A[$i]    = $dir_out . "/sensor-" . ($i+1) . "-out";
    $sensor_stdoutfile_A[$i] = $out_root . "sensor-" . ($i+1) . ".stdout";
    $sensor_classfile_A[$i]  = "sensor-class." . ($i+1) . ".out";
    $sensor_cmd = $execs_H{"sensor"} . " $sensor_minlen $sensor_maxlen $subseq_file_A[$i] $sensor_classfile_A[$i] $sensor_minid_A[$i] $sensor_maxevalue $sensor_dir_out_A[$i] > $sensor_stdoutfile_A[$i]";
    ribo_RunCommand($sensor_cmd, opt_Get("-v", \%opt_HH));
    ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);
  }
  else { 
    $sensor_dir_out_A[$i]    = undef;
    $sensor_stdoutfile_A[$i] = undef;
    $sensor_classfile_A[$i]  = undef;
  }
}

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
