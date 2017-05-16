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
#     option            type       default               group   requires incompat    preamble-output                                    help-output    
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,      undef,                                             "display this help",                                       \%opt_HH, \@opt_order_A);
opt_Add("-f",           "boolean", 0,                        1,    undef, undef,      "forcing directory overwrite",                     "force; if <output directory> exists, overwrite it",       \%opt_HH, \@opt_order_A);
opt_Add("-c",           "boolean", 0,                        1,    undef, undef,      "assert sequences are from cultured organisms",    "assert sequences are from cultured organisms",            \%opt_HH, \@opt_order_A);
opt_Add("-n",           "integer", 0,                        1,    undef, undef,      "use <n> CPUs",                                    "use <n> CPUs",                                            \%opt_HH, \@opt_order_A);
opt_Add("-v",           "boolean", 0,                        1,    undef, undef,      "be verbose",                                      "be verbose; output commands to stdout as they're run",    \%opt_HH, \@opt_order_A);
opt_Add("--keep",       "boolean", 0,                        1,    undef, undef,      "keep all intermediate files",                     "keep all intermediate files that are removed by default", \%opt_HH, \@opt_order_A);
opt_Add("--skipsearch", "boolean", 0,                        1,    undef,  "-f",      "skip search stages, use results from earlier run","skip search stages, use results from earlier run",        \%opt_HH, \@opt_order_A);
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
$opt_group_desc_H{"3"} = "options for saving sequence subsets to files";
opt_Add("--psave",       "boolean",0,                        2,    undef, undef,      "save passing sequences to a file",                            "save passing sequences to a file", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $usage    = "Usage: ribosensor-wrapper.pl [-options] <fasta file to annotate> <output directory>\n";
$usage      .= "\n";
my $synopsis = "ribosensor-wrapper.pl :: analyze ribosomal RNA sequences with profile HMMs and BLASTN";
my $options_okay = 
    &GetOptions('h'            => \$GetOptions_H{"-h"}, 
                'f'            => \$GetOptions_H{"-f"},
                'c'            => \$GetOptions_H{"-c"},
                'n=s'          => \$GetOptions_H{"-n"},
                'v'            => \$GetOptions_H{"-v"},
                'keep'         => \$GetOptions_H{"--keep"}, 
                'skipsearch'   => \$GetOptions_H{"--skipsearch"},
                'Sminlen=s'    => \$GetOptions_H{"--Sminlen"}, 
                'Smaxlen=s'    => \$GetOptions_H{"--Smaxlen"}, 
                'Smaxevalue=s' => \$GetOptions_H{"--Smaxevalue"}, 
                'Sminid1=s'    => \$GetOptions_H{"--Sminid1"}, 
                'Sminid2=s'    => \$GetOptions_H{"--Sminid2"}, 
                'Sminid3=s'    => \$GetOptions_H{"--Sminid3"},
                'Smincovall=s' => \$GetOptions_H{"--Smincovall"},
                'Smincov1=s'   => \$GetOptions_H{"--Smincov1"},
                'Smincov2=s'   => \$GetOptions_H{"--Smincov2"},
                'psave'        => \$GetOptions_H{"--psave"});

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
my @to_remove_A = ();                # array of files to remove at end

# the way we handle the $dir_out differs markedly if we have --skipsearch enabled
# so we handle that separately
if(opt_Get("--skipsearch", \%opt_HH)) { 
  if(-d $dir_out) { 
    # this is what we expect, do nothing
  }
  elsif(-e $dir_out) { 
    die "ERROR with --skipsearch, $dir_out must already exist as a directory, but it exists as a file, delete it first, then run without --skipsearch";
  }
  else { 
    die "ERROR with --skipsearch, $dir_out must already exist as a directory, but it does not. Run without --skipsearch";
  }
}
else {  # --skipsearch not used, normal case
  if(-d $dir_out) { 
    $cmd = "rm -rf $dir_out";
    if(opt_Get("--psave", \%opt_HH)) { 
      die "ERROR you used --psave but directory $dir_out already exists.\nYou can either run with --skipsearch to create the psave file and not redo the searches OR\nremove the $dir_out directory and then rerun with --psave if you really want to redo the search steps";
    }
    elsif(opt_Get("-f", \%opt_HH)) { 
      ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH)); 
    }
    else { 
      die "ERROR directory named $dir_out already exists. Remove it, or use -f to overwrite it."; 
    }
  }
  elsif(-e $dir_out) { 
    $cmd = "rm $dir_out";
    if(opt_Get("-f", \%opt_HH)) { ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH)); }
    else                        { die "ERROR a file named $dir_out already exists. Remove it, or use -f to overwrite it."; }
  }
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

##############################
# define and open output files
##############################
my $unsrt_sensor_gpipe_file = $out_root . ".sensor.unsrt.gpipe"; # unsorted 'gpipe' format sensor output
my $sensor_gpipe_file       = $out_root . ".sensor.gpipe";       # sorted 'gpipe' format sensor output
my $ribo_gpipe_file         = $out_root . ".ribo.gpipe";         # 'gpipe' format ribotyper output
my $combined_gpipe_file     = $out_root . ".gpipe";              # 'gpipe' format combined output
my $passes_sfetch_file      = $out_root . ".pass.sfetch";            # all sequences that passed
my $passes_seq_file         = $out_root . ".pass.fa";            # all sequences that passed

if(! opt_Get("--keep", \%opt_HH)) { 
  push(@to_remove_A, $unsrt_sensor_gpipe_file);
  if(opt_Get("--psave", \%opt_HH)) { 
    push(@to_remove_A, $passes_sfetch_file);
  }
}

my $unsrt_sensor_gpipe_FH = undef; # output file handle for unsorted sensor gpipe file
my $sensor_gpipe_FH       = undef; # output file handle for sorted sensor gpipe file
my $ribo_gpipe_FH         = undef; # output file handle for sorted ribotyper gpipe file
my $combined_gpipe_FH     = undef; # output file handle for the combined gpipe file
open($unsrt_sensor_gpipe_FH, ">", $unsrt_sensor_gpipe_file)  || die "ERROR unable to open $unsrt_sensor_gpipe_file for writing";
open($sensor_gpipe_FH,       ">", $sensor_gpipe_file)        || die "ERROR unable to open $sensor_gpipe_file for writing";
open($ribo_gpipe_FH,         ">", $ribo_gpipe_file)          || die "ERROR unable to open $ribo_gpipe_file for writing";
open($combined_gpipe_FH,     ">", $combined_gpipe_file)      || die "ERROR unable to open $combined_gpipe_file for writing";

###################################################################
# Step 1: Split up input sequence file into 3 files based on length
###################################################################
# we do this before running ribotyper, even though ribotyper is run
# on the full file so that we'll exit if we have a problem in the
# sequence file
my $progress_w = 53; # the width of the left hand column in our progress output, hard-coded
my $start_secs = ribo_OutputProgressPrior("Partitioning sequence file based on sequence lengths", $progress_w, undef, *STDOUT);
my %seqidx_H = (); # key: sequence name, value: index of sequence in original input sequence file (1..$nseq)
my %seqlen_H = (); # key: sequence name, value: length of sequence
my %width_H  = (); # hash, key is "model" or "target", value is maximum length of any model/target
my $tot_nseq = 0;  # total number of sequences in the sequence file
my $tot_nnt  = 0;  # total number of nucleotides in the full sequence file
$width_H{"taxonomy"} = length("SSU.Euk-Microsporidia"); # longest possible classification
$width_H{"strand"}   = length("mixed(S):minus(R)");     # longest possible strand string

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
$tot_nnt  = ribo_ProcessSequenceFile($execs_H{"esl-seqstat"}, $seq_file, $seqstat_file, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH);
$tot_nseq = scalar(keys %seqidx_H);

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
my $ribo_dir_out    = $dir_out . "/ribo-out";
my $ribo_stdoutfile = $out_root . ".ribotyper.stdout";
my $ribotyper_cmd   = $execs_H{"ribo"} . " -f -n $ncpu --inaccept $ribo_model_dir/ssu.arc.bac.accept --scfail --covfail $seq_file $ribo_dir_out > $ribo_stdoutfile";
my $ribo_secs       = 0.; # total number of seconds required for ribotyper command
my $ribo_shortfile  = $ribo_dir_out . "/ribo-out.ribotyper.short.out";
if(! opt_Get("--skipsearch", \%opt_HH)) { 
  $start_secs = ribo_OutputProgressPrior("Running ribotyper on full sequence file", $progress_w, undef, *STDOUT);
  $ribo_secs = ribo_RunCommand($ribotyper_cmd, opt_Get("-v", \%opt_HH));
  ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);
}  

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
my $sensor_secs      = 0.; # total number of seconds required for sensor commands
my $sensor_ncpu      = ($ncpu == 0) ? 1 : $ncpu;

for(my $i = 0; $i < $nseq_parts; $i++) { 
  $sensor_minid_A[$i] = opt_Get("--Sminid" . ($i+1), \%opt_HH);
  if($subseq_nseq_A[$i] > 0) { 
    $sensor_dir_out_A[$i]             = $dir_out . "/sensor-" . ($i+1) . "-out";
    $sensor_stdoutfile_A[$i]          = $out_root . "sensor-" . ($i+1) . ".stdout";
    $sensor_classfile_argument_A[$i]  = "sensor-class." . ($i+1) . ".out";
    $sensor_classfile_fullpath_A[$i]  = $sensor_dir_out_A[$i] . "/sensor-class." . ($i+1) . ".out";
    $sensor_cmd = $execs_H{"sensor"} . " $sensor_minlen $sensor_maxlen $subseq_file_A[$i] $sensor_classfile_argument_A[$i] $sensor_minid_A[$i] $sensor_maxevalue $sensor_ncpu $sensor_dir_out_A[$i] > $sensor_stdoutfile_A[$i]";
    if(! opt_Get("--skipsearch", \%opt_HH)) { 
      $start_secs = ribo_OutputProgressPrior("Running 16S-sensor on seqs of length $spart_desc_A[$i]", $progress_w, undef, *STDOUT);
      $sensor_secs += ribo_RunCommand($sensor_cmd, opt_Get("-v", \%opt_HH));
      ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);
    }
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
$start_secs = ribo_OutputProgressPrior("Parsing and combining 16S-sensor and ribotyper output", $progress_w, undef, *STDOUT);
# parse 16S-sensor file to create gpipe format file
# first unsorted, then sort it.
parse_sensor_files($unsrt_sensor_gpipe_FH, \@sensor_classfile_fullpath_A, \@cpart_minlen_A, \@cpart_maxlen_A, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH);
close($unsrt_sensor_gpipe_FH);

# sort sensor shortfile
output_gpipe_headers($sensor_gpipe_FH, "sensor", \%width_H);
close($sensor_gpipe_FH);

$cmd = "sort -n $unsrt_sensor_gpipe_file >> $sensor_gpipe_file";
ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH));
open($sensor_gpipe_FH, ">>", $sensor_gpipe_file) || die "ERROR, unable to open $sensor_gpipe_file for appending";
output_gpipe_tail($sensor_gpipe_FH, "sensor", \%opt_HH); 
close($sensor_gpipe_FH);

# convert ribotyper output to gpipe 
output_gpipe_headers($ribo_gpipe_FH, "ribotyper", \%width_H);
convert_ribo_short_to_gpipe_file($ribo_gpipe_FH, $ribo_shortfile, \%seqidx_H, \%width_H, \%opt_HH);
output_gpipe_tail($ribo_gpipe_FH, "ribotyper", \%opt_HH); 
close($ribo_gpipe_FH);

# define data structures for statistics/counts that we will output
my @outcome_type_A;      # array of outcome 'types', in order they should be output
my @outcome_cat_A;       # array of outcome 'categories' in order they should be output
my %outcome_ct_HH  = (); # 2D hash of counts of 'outcomes'
                         # 1D key is outcome type, an element from @outcome_type_A
                         # 2D key is outcome category, an element from @outcome_cat_A
                         # value is count
my @herror_type_A  = (); # array of 'human' error types, in order they should be output
my %herror_ct_HH   = (); # 2D hash of counts of 'human' error types, 
                         # 1D key is outcome type, e.g. "RPSF", 
                         # 2D key is human error type, an element from @herror_type_A
                         # value is count
#my @merror_type_A  = (); # array of 'machine' error types, in order they should be output
#my %merror_ct_HH   = (); # 2D hash of counts of 'machine' error types, 
#                         # 1D key is outcome type, e.g. "RPSF", 
#                         # 2D key is machine error type, an element from @merror_type_A
#                         # value is count
@outcome_type_A    = ("RPSP", "RPSF", "RFSP", "RFSF", "*all*");
@outcome_cat_A     = ("total", "pass", "indexer", "submitter", "unmapped");
@herror_type_A     = ("CLEAN_(zero_errors)",
                      "sensor_no",
                      "sensor_toolong", 
                      "sensor_tooshort", 
                      "sensor_imperfect_match",
                      "sensor_misassembly",
                      "sensor_HSPproblem",
                      "sensor_nosimilarity",
                      "sensor_lowsimilarity",
                      "ribotyper_no",
                      "ribotyper_wrongdomain", 
                      "ribotyper_multiplefamilies",
                      "ribotyper_bothstrands",
                      "ribotyper_wrongtaxonomy", 
                      "ribotyper_lowscore",
                      "ribotyper_lowcoverage",
                      "ribotyper_duplicateregion",
                      "ribotyper_inconsistenthits",
                      "ribotyper_multiplehits");
#@merror_type_A     = ()"sensor_no",

initialize_hash_of_hash_of_counts(\%outcome_ct_HH, \@outcome_type_A, \@outcome_cat_A);
initialize_hash_of_hash_of_counts(\%herror_ct_HH,  \@outcome_type_A, \@herror_type_A);

# combine sensor and ribotyper gpipe to get combined gpipe file
output_gpipe_headers($combined_gpipe_FH, "combined", \%width_H);
combine_gpipe_files($combined_gpipe_FH, $sensor_gpipe_file, $ribo_gpipe_file, 
                    \%outcome_ct_HH, \%herror_ct_HH, \%width_H, \%opt_HH);
output_gpipe_tail($combined_gpipe_FH, "combined", \%opt_HH); # 1: output is for ribo, not ribotyper
close($combined_gpipe_FH);

ribo_OutputProgressComplete($start_secs, undef, undef, *STDOUT);

# save output files that were specified with cmdline options
my $nseq_passed    = 0; # number of sequences 
my $nseq_revcomped = 0; # number of sequences reverse complemented
if(opt_Get("--psave", \%opt_HH)) { 
  ($nseq_passed, $nseq_revcomped) = fetch_seqs_given_gpipe_file($execs_H{"esl-sfetch"}, $seq_file, $combined_gpipe_file, "pass", 6, 1, $passes_sfetch_file, $passes_seq_file, \%seqlen_H, \%opt_HH);
}

output_outcome_counts(*STDOUT, \%outcome_ct_HH);
output_error_counts(*STDOUT, "Error counts:", $tot_nseq, \%{$herror_ct_HH{"*all*"}}, \@herror_type_A);

$total_seconds += ribo_SecondsSinceEpoch();
output_timing_statistics(*STDOUT, $tot_nseq, $tot_nnt, $ncpu, $ribo_secs, $sensor_secs, $total_seconds, \%opt_HH);

printf("#\n# Output saved to file $combined_gpipe_file\n");
if((opt_Get("--psave", \%opt_HH)) && ($nseq_passed > 0)) { 
  printf("#\n# The $nseq_passed sequences that passed (with $nseq_revcomped minus strand sequences\n# reverse complemented) saved to file $passes_seq_file\n");
}
printf("#\n#[RIBO-SUCCESS]\n");

###############
# SUBROUTINES #
###############

#################################################################
# Subroutine : fetch_seqs_in_length_range()
# Incept:      EPN, Fri May 12 11:13:46 2017
#
# Purpose:     Use esl-sfetch to fetch sequences in a given length
#              range from <$seq_file> given the lengths in %{$seqlen_HR}.
#
# Arguments: 
#   $sfetch_exec:  path to esl-sfetch executable
#   $seq_file:     sequence file to fetch sequences from
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
#   $FH:           filehandle to output to
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
  my ($FH, $classfile_AR, $minlen_AR, $maxlen_AR, $seqidx_HR, $seqlen_HR, $width_HR, $opt_HHR) = (@_);

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
        # now stop the else, because remainder don't depend on class
        if($strand eq "mixed") { 
          $passfail = "FAIL";
          $failmsg  .= "sensor_misassembly;";
        }
        if(($nhits ne "NA") && ($nhits > 1)) { 
          $passfail = "FAIL";
          $failmsg  .= "sensor_HSPproblem;";
        }
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
        output_gpipe_line($FH, $seqidx_HR->{$seqid}, $seqid, "?", $strand, $passfail, $failmsg, "sensor", $width_HR, $opt_HHR);
      }
    }
  }
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
    if(($max_AR->[$i] == -1) || ($length <= $max_AR->[$i])) { 
      return $i;
    }
  }
  die "ERROR in $sub_name, length $length out of bounds (too long)"; 

  return 0; # never reached
}

#################################################################
# Subroutine : output_gpipe_headers()
# Incept:      EPN, Sat May 13 05:51:17 2017
#
# Purpose:     Output column headers to a gpipe format output
#              file for either sensor or ribotyper.
#              
# Arguments: 
#   $FH:        file handle to output to
#   $type:      'sensor', 'ribotyper', or 'combined'
#   $width_HR:  ref to hash, keys include "model" and "target", 
#               value is width (maximum length) of any target/model
#
# Returns:     Nothing.
# 
# Dies:        Never.
#
################################################################# 
sub output_gpipe_headers { 
  my $nargs_expected = 3;
  my $sub_name = "output_gpipe_headers";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $type, $width_HR) = (@_);

  my $index_dash_str  = "#" . ribo_GetMonoCharacterString($width_HR->{"index"}-1, "-");
  my $target_dash_str = ribo_GetMonoCharacterString($width_HR->{"target"}, "-");
  my $tax_dash_str    = ribo_GetMonoCharacterString($width_HR->{"taxonomy"}, "-");
  my $strand_dash_str = ribo_GetMonoCharacterString($width_HR->{"strand"}, "-");

  if(($type eq "sensor") || ($type eq "ribotyper")) { 
    printf $FH ("%-*s  %-*s  %-*s  %-*s  %4s  %s\n", 
                $width_HR->{"index"},    "#idx", 
                $width_HR->{"target"},   "sequence", 
                $width_HR->{"taxonomy"}, "taxonomy",
                $width_HR->{"strand"},   "strand", 
                "p/f", "error(s)");
    printf $FH ("%s  %s  %s  %s  %s  %s\n", $index_dash_str, $target_dash_str, $tax_dash_str, $strand_dash_str, "----", "--------");
  }
  elsif($type eq "combined") { 
    printf $FH ("%-*s  %-*s  %-*s  %-*s  %4s  %9s  %s\n", 
                $width_HR->{"index"},    "#idx", 
                $width_HR->{"target"},   "sequence", 
                $width_HR->{"taxonomy"}, "taxonomy",
                $width_HR->{"strand"},   "strand", 
                "type", "failsto", "error(s)");
    printf $FH ("%s  %s  %s  %s  %s  %s  %s\n", $index_dash_str, $target_dash_str, $tax_dash_str, $strand_dash_str, "----", "---------", "--------");
  }

  return;
}

#################################################################
# Subroutine : output_gpipe_tail()
# Incept:      EPN, Sat May 13 06:17:57 2017
#
# Purpose:     Output explanation of columns to gpipe format 
#              file for either sensor or ribotyper.
#              
# Arguments: 
#   $FH:         file handle to output to
#   $type:       'sensor', 'ribotyper', or 'combined'
#   $opt_HHR:    reference to 2D hash of cmdline options
#
# Returns:     Nothing.
# 
# Dies:        Never.
#
################################################################# 
sub output_gpipe_tail { 
  my $nargs_expected = 3;
  my $sub_name = "output_gpipe_tail";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $type, $opt_HHR) = (@_);

  printf $FH ("#\n");
  printf $FH ("# Explanation of columns:\n");
  printf $FH ("#\n");
  printf $FH ("# Column 1 [idx]:      index of sequence in input sequence file\n");
  printf $FH ("# Column 2 [target]:   name of target sequence\n");
  printf $FH ("# Column 3 [taxonomy]: inferred taxonomy of sequence%s\n", ($type eq "sensor") ? "(always '-' because 16S-sensor does not infer taxonomy)" : "");
  printf $FH ("# Column 4 [strnd]:    strand ('plus' or 'minus') of best-scoring hit\n");
  if(($type eq "sensor") || ($type eq "ribotyper")) { 
    printf $FH ("# Column 5 [p/f]:      PASS or FAIL\n");
    printf $FH ("# Column 6 [error(s)]: reason(s) for failure (see 00README.txt)\n");
  }
  elsif($type eq "combined") { 
    printf $FH ("# Column 5 [type]:     \"R<1>S<2>\" <1> is 'P' if passes ribotyper, 'F' if fails; <2> is same, but for sensor\n");
    printf $FH ("# Column 6 [failsto]:  'PASS' if sequence passes\n");
    printf $FH ("#                      'indexer'   to fail to indexer ('indexer*' if interesting situation)\n");
    printf $FH ("#                      'submitter' to fail to submitter\n");
    printf $FH ("#                      '?' if situation is not covered in the code\n");
    printf $FH ("# Column 7 [error(s)]: reason(s) for failure (see 00README.txt)\n");
  }
  else { 
    die "ERROR in $sub_name, unexpected type: $type (should be 'sensor', 'ribotyper', or 'combined'";
  }
  
  output_errors_explanation($FH, $opt_HHR);

  return;
}

#################################################################
# Subroutine : output_errors_explanation()
# Incept:      EPN, Mon May 15 05:25:51 2017
#
# Purpose:     Output explanation of error(s) in a gpipe file.
#              
# Arguments: 
#   $FH:       file handle to output to
#   $opt_HHR:  reference to options 2D hash
#
# Returns:     Nothing.
# 
# Dies:        Never.
#
################################################################# 
sub output_errors_explanation { 
  my $nargs_expected = 2;
  my $sub_name = "output_errors_explanation";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $opt_HHR) = (@_);

#  print $FH ("#\n");
#  print $FH ("# Explanation of possible values in error(s) column:\n");
#  print $FH ("#\n");
#  print $FH ("# This column will include a '-' if none of the error(s) listed below are detected.\n");
#  print $FH ("# Or it will contain one or more of the following types of messages. There are no\n");
#  print $FH ("# whitespaces in this field. Errors from 16S-sensor begin with \'sensor\'. Errors\n");
#  print $FH ("# from ribotyper begin with 'ribotyper'.\n");
#  print $FH ("#\n");

  return;
}

#################################################################
# Subroutine : convert_ribo_short_to_gpipe_file()
# Incept:      EPN, Mon May 15 05:35:28 2017
#
# Purpose:     Convert a ribotyper short format output file 
#              to gpipe format. 
#
# Arguments: 
#   $FH:        filehandle to output to
#   $shortfile: name of ribotyper short file
#   $seqidx_HR: ref to hash of sequence indices
#   $width_HR:  ref to hash with max lengths of sequence index and target
#   $opt_HHR:   ref to 2D hash of cmdline options
# 
# Returns:     void
#
# Dies:        if short file is in unexpected format
#
################################################################# 
sub convert_ribo_short_to_gpipe_file { 
  my $nargs_expected = 5;
  my $sub_name = "convert_ribo_short_to_gpipe_file";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($FH, $shortfile, $seqidx_HR, $width_HR, $opt_HHR) = (@_);

  my @el_A         = ();    # array of elements on a line
  my @ufeature_A   = ();    # array of unexpected features on a line
  my $ufeature     = undef; # a single unexpected feature
  my $ufeature_str = undef; # a single unexpected feature
  my $line         = undef; # a line of input
  my $failmsg      = undef; # list of errors for the sequence
  my $idx          = undef; # a sequence index
  my $seqid        = undef; # name of a sequence
  my $class        = undef; # class of a sequence
  my $strand       = undef; # strand of a sequence
  my $passfail     = undef; # PASS or FAIL for a sequence
  my $i;                  # a counter

  open(IN, $shortfile) || die "ERROR unable to open $shortfile for reading in $sub_name"; 
  while($line = <IN>) { 
    if($line !~ m/^\#/) { 
      # example lines:
      #idx  target                                         classification         strnd   p/f  unexpected_features
      #---  ---------------------------------------------  ---------------------  -----  ----  -------------------
      #14    00220::Euplotes_aediculatus.::M14590           SSU.Eukarya            plus   FAIL  *unacceptable_model
      #15    00229::Oxytricha_granulifera.::AF164122        SSU.Eukarya            minus  FAIL  *unacceptable_model;opposite_strand
      chomp $line;
      
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 6) { die "ERROR unable to parse ribotyper short file line: $line"; }
      ($idx, $seqid, $class, $strand, $passfail, $ufeature_str) = (@el_A);
      if($strand eq "-") { $strand = "NA"; }
      $failmsg = "";
      
      # sanity checks
      if(! exists $seqidx_HR->{$seqid}) { 
      die "ERROR in $sub_name, found unexpected sequence $seqid\n";
      }
      if($seqidx_HR->{$seqid} != $idx) { 
        die "ERROR in $sub_name, sequence $seqid has index $idx but expected index $seqidx_HR->{$seqid}.\n";
      }      
      
      if($ufeature_str eq "-") { 
        # sanity check
        if($passfail ne "PASS") { 
          die "ERROR in $sub_name, sequence $seqid has no unexpected features, but does not PASS:\n$line\n";
        }
        output_gpipe_line($FH, $idx, $seqid, $class, $strand, $passfail, "-", "ribotyper", $width_HR, $opt_HHR);
      }
      else { # ufeature_str ne "-", look at each unexpected feature and convert to gpipe error string
        @ufeature_A = split(";", $ufeature_str);
        foreach $ufeature (@ufeature_A) { 
          if($ufeature =~ m/no\_hits/) { 
            $failmsg .= "ribotyper_no;";
            $passfail = "FAIL";
          }
          if($ufeature =~ m/hits\_to\_more\_than\_one\_family/) { 
            $failmsg .= "ribotyper_multiplefamilies;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/hits\_on\_both\_strands/) { 
            $failmsg .= "ribotyper_bothstrands;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/unacceptable\_model/) { 
            $failmsg .= "ribotyper_wrongtaxonomy;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/low\_score\_per\_posn/) { 
            $failmsg .= "ribotyper_lowscore;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/low\_total\_coverage/) { 
            $failmsg .= "ribotyper_lowcoverage;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/duplicate\_model\_region/) { 
            $failmsg .= "ribotyper_duplicateregion;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/inconsistent\_hit\_order/) { 
            $failmsg .= "ribotyper_inconsistenthits;";
            $passfail = "FAIL";
          }        
          if($ufeature =~ m/multiple_hits_to_best_model/) { 
            $failmsg .= "ribotyper_multiplehits;";
            $passfail = "FAIL";
          }
        }
        if($failmsg eq "") { 
          if($passfail ne "PASS") { 
            die "ERROR in $sub_name, sequence $seqid has no unexpected features that cause errors, but does not PASS:\n$line\n";
          }
          $failmsg = "-"; 
        }
        output_gpipe_line($FH, $idx, $seqid, $class, $strand, $passfail, $failmsg, "ribotyper", $width_HR, $opt_HHR);
      } # end of else entered if $ufeature_str ne "-"
    }
 }   
  return;
}
  
#################################################################
# Subroutine : output_gpipe_line()
# Incept:      EPN, Mon May 15 05:46:28 2017
#
# Purpose:     Output a single line to a gpipe file file handle.
#
# Arguments: 
#   $FH:          filehandle to output to
#   $idx:         sequence index
#   $seqid:       sequence identifier
#   $class:       classification value
#   $strand:      strand value
#   $passfail:    "PASS" or "FAIL"
#   $failmsg:     failure message
#   $type:        "sensor", "ribotyper" or "combined"
#   $width_HR:    ref to hash with max lengths of sequence index and target
#   $opt_HHR:     ref to 2D hash of cmdline options
#
# Returns:     "fails_to" string, only if $type eq "combined" else ""
#
# Dies:        never
#
################################################################# 
sub output_gpipe_line { 
  my $nargs_expected = 10;
  my $sub_name = "output_gpipe_line";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($FH, $idx, $seqid, $class, $strand, $passfail, $failmsg, $type, $width_HR, $opt_HHR) = (@_);

  my $failsto = "";

  if(($type eq "sensor") || ($type eq "ribotyper")) { 
    printf $FH ("%-*d  %-*s  %-*s  %-*s  %4s  %s\n", 
                $width_HR->{"index"},    $idx, 
                $width_HR->{"target"},   $seqid, 
                $width_HR->{"taxonomy"}, $class, 
                $width_HR->{"strand"},   $strand, 
                $passfail, $failmsg);
  }
  elsif($type eq "combined") { 
    $failsto = determine_fails_to_string($passfail, $failmsg, $opt_HHR);
    printf $FH ("%-*d  %-*s  %-*s  %-*s  %4s  %9s  %s\n", 
                $width_HR->{"index"},    $idx, 
                $width_HR->{"target"},   $seqid, 
                $width_HR->{"taxonomy"}, $class, 
                $width_HR->{"strand"},   $strand, 
                $passfail, $failsto, $failmsg);
  }
  else { 
    die "ERROR in $sub_name, unexpected type: $type (should be 'sensor', 'ribotyper', or 'combined'";
  }

  return $failsto;
}

#################################################################
# Subroutine : combine_gpipe_files()
# Incept:      EPN, Mon May 15 09:08:38 2017
#
# Purpose:     Combine the information in a gpipe file from 
#              sensor and ribotyper into a single file.
#
# Arguments: 
#   $FH:                filehandle to output to
#   $sensor_gpipe_file: name of sensor gpipe file to read
#   $ribo_gpipe_file:   name of ribotyper gpipe file to read
#   $outcome_ct_HHR:    ref to 2D hash of counts of outcomes,
#                       1D key: "RPSP", "RPSF", "RFSP", "RFSF", "*all*"
#                       2D key: "total", "pass", "indexer", "submitter", "unmapped"
#                       values: counts of sequences
#   $herror_ct_HHR:     ref to 2D hash of counts of human errors
#                       1D key: "RPSP", "RPSF", "RFSP", "RFSF", "*all*"
#                       2D key: name of human error (e.g. 'ribotyper_no')
#                       values: counts of sequences
#   $width_HR:          ref to hash with max lengths of sequence index, target, and classifications
#   $opt_HHR:           ref to 2D hash of cmdline options
# 
# Returns:     void
#
# Dies:        if there's a problem parsing the gpipe files
#
################################################################# 
sub combine_gpipe_files { 
  my $nargs_expected = 7;
  my $sub_name = "combine_gpipe_files";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($FH, $sensor_gpipe_file, $ribo_gpipe_file, $outcome_ct_HHR, $herror_ct_HHR, $width_HR, $opt_HHR) = (@_);

  my @sel_A    = ();    # array of elements on a sensor line
  my @rel_A    = ();    # array of elements on a ribotyper line
  my $sline    = undef; # a line of sensor input
  my $rline    = undef; # a line of ribotyper input
  my ($sidx,      $ridx,      $idx);      # a sensor, ribotyper, and combined sequence index
  my ($sseqid,    $rseqid,    $seqid);    # a sensor, ribotyper, and combined sequence identifier
  my ($sclass,    $rclass,    $class);    # a sensor, ribotyper, and combined classification string
  my ($sstrand,   $rstrand,   $strand);   # a sensor, ribotyper, and combined strand
  my ($spassfail, $rpassfail, $passfail); # a sensor, ribotyper, and combined pass/fail string
  my ($sfailmsg,  $rfailmsg,  $failmsg);  # a sensor, ribotyper, and combined failure message
  my $i;                # a counter
  my $slidx    = 0;     # line number in sensor file we're currently on
  my $rlidx    = 0;     # line number in ribotyper file we're currently on
  my $keep_going = 1;     # flag to keep reading the input files, set to '0' to stop
  my $have_sline = undef; # '1' if we have a valid sensor line
  my $have_rline = undef; # '1' if we have a valid ribotyper line
  my $out_lidx = 0;       # number of lines output
  my $failsto_str = undef; # string of where sequence fails to ('indexer' or 'submitter') or 'pass' or 'unmapped'

  open(SIN, $sensor_gpipe_file) || die "ERROR unable to open $sensor_gpipe_file for reading in $sub_name"; 
  open(RIN, $ribo_gpipe_file)   || die "ERROR unable to open $ribo_gpipe_file for reading in $sub_name"; 

  # we know that the first few lines of both files are comment lines, that begin with "#", chew them up
  $sline = <SIN>;
  $slidx++;
  while((defined $sline) && ($sline =~ m/^\#/)) { 
    $sline = <SIN>;
    $slidx++;
  }

  $rline = <RIN>;
  $rlidx++;
  while((defined $rline) && ($rline =~ m/^\#/)) { 
    $rline = <RIN>;
    $rlidx++;
  }

  $keep_going = 1;
  while($keep_going) { 
    my $have_sline = ((defined $sline) && ($sline !~ m/^\#/)) ? 1 : 0;
    my $have_rline = ((defined $rline) && ($rline !~ m/^\#/)) ? 1 : 0;
    if($have_sline && $have_rline) { 
      chomp $sline;
      chomp $rline;
      # example lines
      ##idx  sequence                                       taxonomy  strnd   p/f  error(s)
      ##---  ---------------------------------------------  --------  -----  ----  --------
      #1     00052::Halobacterium_sp.::AE005128                 ?      plus  PASS  -
      #2     00013::Methanobacterium_formicicum::M36508         ?      plus  PASS  -

      my @sel_A = split(/\s+/, $sline);
      my @rel_A = split(/\s+/, $rline);

      if(scalar(@sel_A) != 6) { die "ERROR in $sub_name, unable to parse sensor gpipe line: $sline"; }
      if(scalar(@rel_A) != 6) { die "ERROR in $sub_name, unable to parse ribotyper gpipe line: $rline"; }

      ($sidx, $sseqid, $sclass, $sstrand, $spassfail, $sfailmsg) = (@sel_A);
      ($ridx, $rseqid, $rclass, $rstrand, $rpassfail, $rfailmsg) = (@rel_A);

      if($sidx   != $ridx)   { die "ERROR In $sub_name, index mismatch\n$sline\n$rline\n"; }
      if($sseqid ne $rseqid) { die "ERROR In $sub_name, sequence name mismatch\n$sline\n$rline\n"; }

      if($sstrand ne $rstrand) { 
        if(($sstrand ne "NA") && ($rstrand ne "NA")) { 
          $strand = $sstrand . "(S):" . $rstrand . "(R)";
        }
        elsif(($sstrand eq "NA") && ($rstrand ne "NA")) { 
          $strand = $rstrand;
        }
        elsif(($sstrand ne "NA") && ($rstrand eq "NA")) { 
          $strand = $sstrand;
        }
      }
      else { # $sstrand eq $rstrand
        $strand = $sstrand; 
      } 

      if($rpassfail eq "FAIL") { $passfail  = "RF"; }
      else                     { $passfail  = "RP"; }
      if($spassfail eq "FAIL") { $passfail .= "SF"; }
      else                     { $passfail .= "SP"; }

      if   ($sfailmsg eq "-" && $rfailmsg eq "-") { $failmsg = "-"; }
      elsif($sfailmsg ne "-" && $rfailmsg eq "-") { $failmsg = $sfailmsg; }
      elsif($sfailmsg eq "-" && $rfailmsg ne "-") { $failmsg = $rfailmsg; }
      elsif($sfailmsg ne "-" && $rfailmsg ne "-") { $failmsg = $sfailmsg . $rfailmsg; }

      $failsto_str = output_gpipe_line($FH, $sidx, $sseqid, $rclass, $strand, $passfail, $failmsg, "combined", $width_HR, $opt_HHR); # 1: combined file
      $out_lidx++;
      # update counts of outcomes 
      $outcome_ct_HHR->{"*all*"}{"total"}++;
      $outcome_ct_HHR->{"*all*"}{$failsto_str}++;
      $outcome_ct_HHR->{$passfail}{"total"}++;
      $outcome_ct_HHR->{$passfail}{$failsto_str}++;

      # update counts of errors
      update_error_count_hash(\%{$herror_ct_HHR->{"*all*"}},   ($failmsg eq "-") ? "CLEAN_(zero_errors)" : $failmsg);
      update_error_count_hash(\%{$herror_ct_HHR->{$passfail}}, ($failmsg eq "-") ? "CLEAN_(zero_errors)" : $failmsg);

      # get new lines
      $sline = <SIN>;
      $rline = <RIN>;
      $slidx++;
      $rlidx++;
    }
    # check for some unexpected errors
    elsif(($have_sline) && (! $have_rline)) { 
      die "ERROR in $sub_name, ran out of sequences from ribotyper gpipe file before sensor gpipe file";
    }
    elsif((! $have_sline) && ($have_rline)) { 
      die "ERROR in $sub_name, ran out of sequences from sensor gpipe file before ribotyper gpipe file"; 
    }
    else { # don't have either line
      $keep_going = 0;
    }
  }

  if($out_lidx == 0) { 
    die "ERROR in $sub_name, did not output information on any sequences"; 
  }

  return;
}

  
#################################################################
# Subroutine : determine_fails_to_string()
# Incept:      EPN, Mon May 15 10:42:52 2017
#
# Purpose:     Given a 4 character ribotyper/sensor pass fail type
#              of either:
#              RPSP: passes both ribotyper and sensor
#              RPSF: passes ribotyper, fails sensor
#              RFSP: fails ribotyper, passes sensor
#              RFSF: fails both ribotyper and sensor
# 
#              And a string that includes all gpipe errors separated
#              by semi-colons, determine if this sequence either:
#              1) passes             (return "PASS")
#              2) fails to indexer   (return "indexer")
#              3) fails to submitter (return "submitter")
#             
# Arguments: 
#   $pftype:      "RPSP", "RPSF", "RFSP", or "RFSF"
#   $failmsg:     all gpipe error separated by ";"
#   $opt_HHR:     ref to 2D hash of cmdline options
#
# Returns:     void
#
# Dies:        never
#
################################################################# 
sub determine_fails_to_string { 
  my $nargs_expected = 3;
  my $sub_name = "determine_fails_to_string";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($pftype, $failmsg, $opt_HHR) = (@_);

  if($pftype eq "RPSP") { 
    if($failmsg ne "-") { # failmsg should be empty
      die "ERROR in $sub_name, pftype: $pftype, but failmsg is not empty: $failmsg"; 
    }
    return "pass";
  }
  elsif($pftype eq "RFSF") { 
    if($failmsg eq "-") { # failmsg should not be empty
      die "ERROR in $sub_name, pftype: $pftype, but failmsg is empty: $failmsg"; 
    }
    if($failmsg !~ m/sensor/) { # failmsg should contain at least one sensor error
      die "ERROR in $sub_name, pftype: $pftype, but failmsg does not contain a sensor error: $failmsg"; 
    }
    if($failmsg !~ m/ribotyper/) { # failmsg should contain at least one ribotyper error
      die "ERROR in $sub_name, pftype: $pftype, but failmsg does not contain a ribotyper error: $failmsg"; 
    }

    # can we determine submitter/indexer based on sensor errors? 
    if(($failmsg =~ m/sensor\_misassembly/)   || 
       ($failmsg =~ m/sensor\_lowsimilarity/) || 
       ($failmsg =~ m/sensor\_no/)) { 
      return "submitter"; 
    }
    elsif($failmsg =~ m/sensor\_HSPproblem/) { 
      return "indexer"; 
    }
    # we can't determine submitter/indexer based on sensor errors, 
    # can we determine submitter/indexer based on ribotyper errors? 
    elsif(($failmsg =~ m/ribotyper\_no/) || 
          ($failmsg =~ m/ribotyper\_bothstrands/) ||
          ($failmsg =~ m/ribotyper\_duplicateregion/) ||
          ($failmsg =~ m/ribotyper\_inconsistenthits/) ||
          ($failmsg =~ m/ribotyper\_lowscore/)) {
      return "submitter";
    }
    elsif(($failmsg =~ m/ribotyper\_lowcoverage/)  || 
          ($failmsg =~ m/ribotyper\_multiplehits/) || 
          ($failmsg =~ m/ribotyper\_wrongtaxonomy/)) { 
      return "indexer";
    }
    else { 
      return "unmapped"; 
      # die "ERROR in $sub_name, unmapped situation $pftype $failmsg\n";
    }
  }
  elsif($pftype eq "RFSP") { 
    if($failmsg eq "-") { # failmsg should not be empty
      die "ERROR in $sub_name, pftype: $pftype, but failmsg is empty: $failmsg"; 
    }
    if($failmsg =~ m/sensor/) { # failmsg should contain at least one sensor error
      die "ERROR in $sub_name, pftype: $pftype, but failmsg contains a sensor error: $failmsg"; 
    }
    if($failmsg !~ m/ribotyper/) { # failmsg should contain at least one ribotyper error
      die "ERROR in $sub_name, pftype: $pftype, but failmsg does not contain a ribotyper error: $failmsg"; 
    }

    if($failmsg =~ m/ribotyper\_multiplefamilies/) { 
      return "submitter"; 
    }
    elsif($failmsg =~ m/ribotyper\_wrongtaxonomy/) { 
      return "indexer"; 
    }
    else { 
#      return "indexer*";  # * = share with Alejandro and Eric
      return "indexer";
    }
  }

  elsif($pftype eq "RPSF") {  # most complicated case
    if($failmsg eq "-") { # failmsg should not be empty
      die "ERROR in $sub_name, pftype: $pftype, but failmsg is empty: $failmsg"; 
    }
    if($failmsg !~ m/sensor/) { # failmsg should contain at least one sensor errors
      die "ERROR in $sub_name, pftype: $pftype, but failmsg contains a sensor error: $failmsg"; 
    }
    if($failmsg =~ m/ribotyper/) { # failmsg should not contain any ribotyper errors
      die "ERROR in $sub_name, pftype: $pftype, but failmsg does not contain a ribotyper error: $failmsg"; 
    }

    my $is_cultured = opt_Get("-c", $opt_HHR);
    if($failmsg =~ m/sensor\_misassembly/) { 
      return "submitter";
    }
    if($failmsg eq "sensor_HSPproblem;") { # HSPproblem is only error
      return "indexer";
    }
    if((($failmsg =~ m/sensor\_lowsimilarity/) || 
        ($failmsg =~ m/sensor\_no/)            || 
        ($failmsg =~ m/sensor\_imperfect\_match/)) # either 'lowsimilarity' or 'no' or 'imperfect_match' error
       && ($failmsg !~ m/sensor\_misassembly/)) { # misassembly error not present
      if($is_cultured) { 
        return "submitter";
      }
      else { 
        if($failmsg =~ m/sensor\_HSPproblem/) { 
          return "indexer";
        }
        else { 
          return "pass";
        }
      }
    }
  }

  die "ERROR in $sub_name, unaccounted for case\npftype: $pftype\nfailmsg: $failmsg\n";
  return ""; # 
}

#################################################################
# Subroutine: output_outcome_counts()
# Incept:     EPN, Mon May 15 11:51:12 2017
#
# Purpose:    Output the tabular outcome counts.
#
# Arguments:
#   $FH:             output file handle
#   $outcome_ct_HHR: ref to the outcome count 2D hash
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub output_outcome_counts { 
  my $sub_name = "output_outcome_counts";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $outcome_ct_HHR) = (@_);

  # determine max width of each column
  my %width_H = ();  # key: name of column, value max width for column
  my $type;          # a 1D key
  my $category;      # a 2D key

  $width_H{"type"}      = length("type");
  $width_H{"total"}     = length("total");
  $width_H{"pass"}      = length("pass");
  $width_H{"indexer"}   = length("indexer");
  $width_H{"submitter"} = length("submitter");
  $width_H{"unmapped"}  = length("unmapped");

  foreach $type (keys %{$outcome_ct_HHR}) { 
    if(length($type) > $width_H{"type"}) { 
      $width_H{"type"} = length($type);
    }
    foreach $category (keys %{$outcome_ct_HHR->{$type}}) { 
      if(length($outcome_ct_HHR->{$type}{$category}) > $width_H{$category}) { 
        $width_H{$category} = length($outcome_ct_HHR->{$type}{$category}); 
      }
    }
  }

  printf $FH ("#\n");
  printf $FH ("# Outcome counts:\n");
  printf $FH ("#\n");
  
  # line 1
  printf $FH ("# %-*s  %*s  %*s  %*s  %*s  %*s\n",
                  $width_H{"type"},      "type",
                  $width_H{"total"},     "total",
                  $width_H{"pass"},      "pass", 
                  $width_H{"indexer"},   "indexer", 
                  $width_H{"submitter"}, "submitter",
                  $width_H{"unmapped"},  "unmapped");
  # line 2
  printf $FH ("# %-*s  %*s  %*s  %*s  %*s  %*s\n", 
                  $width_H{"type"},      ribo_GetMonoCharacterString($width_H{"type"}, "-"),
                  $width_H{"total"},     ribo_GetMonoCharacterString($width_H{"total"}, "-"),
                  $width_H{"pass"},      ribo_GetMonoCharacterString($width_H{"pass"}, "-"),
                  $width_H{"indexer"},   ribo_GetMonoCharacterString($width_H{"indexer"}, "-"),
                  $width_H{"submitter"}, ribo_GetMonoCharacterString($width_H{"submitter"}, "-"),
                  $width_H{"unmapped"},  ribo_GetMonoCharacterString($width_H{"unmapped"}, "-"));
  
  foreach $type ("RPSP", "RPSF", "RFSP", "RFSF", "*all*") { 
    if($type eq "*all*") { print $FH "#\n"; }
    printf $FH ("  %-*s  %*d  %*d  %*d  %*d  %*d\n", 
                $width_H{"type"},      $type,
                $width_H{"total"},     $outcome_ct_HHR->{$type}{"total"}, 
                $width_H{"pass"},      $outcome_ct_HHR->{$type}{"pass"}, 
                $width_H{"indexer"},   $outcome_ct_HHR->{$type}{"indexer"}, 
                $width_H{"submitter"}, $outcome_ct_HHR->{$type}{"submitter"}, 
                $width_H{"unmapped"},  $outcome_ct_HHR->{$type}{"unmapped"}); 
  }

  return;
}

#################################################################
# Subroutine: output_error_counts()
# Incept:     EPN, Tue May 16 09:16:49 2017
#
# Purpose:    Output the tabular error counts for a single category,
#             usually '*all*'.
#
# Arguments:
#   $FH:       output file handle
#   $title:    string to call this table
#   $tot_nseq: total number of sequences in input
#   $ct_HR:    ref to the count 2D hash
#   $key_AR:   ref to array of 1D keys
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub output_error_counts { 
  my $sub_name = "output_error_counts";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $title, $tot_nseq, $ct_HR, $key_AR) = (@_);

  # determine max width of each column
  my %width_H = ();  # key: name of column, value max width for column
  my $error;         # an error name, a 1D key

  $width_H{"error"}    = length("error");
  $width_H{"seqs"}     = length("of seqs");
  $width_H{"fraction"} = length("fraction");

  foreach $error (@{$key_AR}) { 
    if(! exists $ct_HR->{$error}) { 
      die "ERROR in $sub_name, count for error $error does not exist";
    }
    if(($ct_HR->{$error} > 0) && (length($error) > $width_H{"error"})) { 
      $width_H{"error"} = length($error);
    }
  }

  printf $FH ("#\n");
  printf $FH ("# $title\n");
  printf $FH ("#\n");
  
  # line 1 
  printf $FH ("# %-*s  %-*s  %*s\n",
                  $width_H{"error"},    "", 
                  $width_H{"seqs"},     "number",
                  $width_H{"fraction"}, "fraction");
  
  # line 2
  printf $FH ("# %-*s  %-*s  %*s\n",
                  $width_H{"error"},    "error", 
                  $width_H{"seqs"},     "of seqs",
                  $width_H{"fraction"}, "of seqs");

  # line 3
  printf $FH ("# %-*s  %-*s  %*s\n", 
                  $width_H{"error"},    ribo_GetMonoCharacterString($width_H{"error"}, "-"),
                  $width_H{"seqs"},     ribo_GetMonoCharacterString($width_H{"seqs"}, "-"),
                  $width_H{"fraction"}, ribo_GetMonoCharacterString($width_H{"fraction"}, "-"));

  foreach $error (@{$key_AR}) { 
    if(($ct_HR->{$error} > 0) || ($error eq "CLEAN_(zero_errors)")) { 
      printf $FH ("  %-*s  %*d  %*.5f\n", 
                      $width_H{"error"},    $error,
                      $width_H{"seqs"},     $ct_HR->{$error},
                      $width_H{"fraction"}, $ct_HR->{$error} / $tot_nseq);
    }
  }
  printf $FH ("#\n");
  
  return;
  
}


#################################################################
# Subroutine: initialize_hash_of_hash_of_counts()
# Incept:     EPN, Tue May 16 06:26:59 2017
#
# Purpose:    Initialize a 2D hash of counts given arrays that
#             include the 1D and 2D keys.
#
# Arguments:
#   $ct_HHR:  ref to the count 2D hash
#   $key1_AR: ref to array of 1D keys
#   $key2_AR: ref to array of 2D keys
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub initialize_hash_of_hash_of_counts { 
  my $sub_name = "initialize_hash_of_hash_of_counts()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($ct_HHR, $key1_AR, $key2_AR) = (@_);
  
  foreach my $key1 (@{$key1_AR}) { 
    %{$ct_HHR->{$key1}} = ();
    foreach my $key2 (@{$key2_AR}) { 
      $ct_HHR->{$key1}{$key2} = 0;
    }
  }

  return;
}

#################################################################
# Subroutine: update_error_count_hash()
# Incept:     EPN, Tue May 16 09:09:07 2017
#
# Purpose:    Update a hash of counts of errors given a string
#             that has those errors separated by a ';'
#             include the 1D and 2D keys.
#
# Arguments:
#   $ct_HR:   ref to the count hash, each key is a possible error
#   $errstr:  string of >= 1 errors, each separated by a ';'
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub update_error_count_hash { 
  my $sub_name = "update_error_count_hash()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($ct_HR, $errstr) = (@_);

  if($errstr eq "-") { die "ERROR in $sub_name, no errors in error string"; }
  
  my @err_A = split(";", $errstr);
  foreach my $err (@err_A) { 
    if(! exists $ct_HR->{$err}) { 
      die "ERROR in $sub_name, unknown error string $err"; 
    }
    $ct_HR->{$err}++;
  }

  return;
}

#################################################################
# Subroutine: output_timing_statistics()
# Incept:     EPN, Mon May 15 15:33:17 2017
#
# Purpose:    Output timing statistics.
#
# Arguments:
#   $FH:              output file handle
#   $tot_nseq:        number of sequences in input file
#   $tot_nnt:         number of nucleotides in input file
#   $ncpu:            number of CPUs used to do searches
#   $ribo_secs:       number of seconds required for ribotyper
#   $sensor_secs:     number of seconds required for sensor
#   $tot_secs:        number of seconds required for entire script
#   $opt_HHR:         ref to 2D hash of cmdline options
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub output_timing_statistics { 
  my $sub_name = "output_timing_statistics";
  my $nargs_expected = 8;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($FH, $tot_nseq, $tot_nnt, $ncpu, $ribo_secs, $sensor_secs, $tot_secs, $opt_HHR) = (@_);

  if($ncpu == 0) { $ncpu = 1; } 

  # get total number of sequences and nucleotides for each round from %{$class_stats_HHR}

  # determine max width of each column
  my %width_H = ();  # key: name of column, value max width for column
  my $stage;         # a class, 1D key in ${%class_stats_HHR}

  $width_H{"stage"}    = length("ribotyper");
  $width_H{"nseq"}     = length("num seqs");
  $width_H{"seqsec"}   = 7;
  $width_H{"ntsec"}    = 10;
  $width_H{"ntseccpu"} = 10;
  $width_H{"total"}    = 23;
  
  printf $FH ("#\n");
  printf $FH ("# Timing statistics:\n");
  printf $FH ("#\n");

  # line 1
  printf $FH ("# %-*s  %*s  %*s  %*s  %*s  %*s\n",
                  $width_H{"stage"},    "stage",
                  $width_H{"nseq"},     "num seqs",
                  $width_H{"seqsec"},   "seq/sec",
                  $width_H{"ntsec"},    "nt/sec",
                  $width_H{"ntseccpu"}, "nt/sec/cpu",
                  $width_H{"total"},    "total time");

  
  # line 2
  printf $FH ("# %-*s  %*s  %*s  %*s  %*s  %*s\n",
                  $width_H{"stage"},    ribo_GetMonoCharacterString($width_H{"stage"}, "-"),
                  $width_H{"nseq"},     ribo_GetMonoCharacterString($width_H{"nseq"}, "-"),
                  $width_H{"seqsec"},   ribo_GetMonoCharacterString($width_H{"seqsec"}, "-"),
                  $width_H{"ntsec"},    ribo_GetMonoCharacterString($width_H{"ntsec"}, "-"),
                  $width_H{"ntseccpu"}, ribo_GetMonoCharacterString($width_H{"ntseccpu"}, "-"),
                  $width_H{"total"},    ribo_GetMonoCharacterString($width_H{"total"}, "-"));
  
  $stage = "ribotyper";
  if(opt_Get("--skipsearch", $opt_HHR)) { 
    printf $FH ("  %-*s  %*d  %*s  %*s  %*s  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   "-",
                $width_H{"ntsec"},    "-",
                $width_H{"ntseccpu"}, "-",
                $width_H{"total"},    "-");
  }
  else { 
    printf $FH ("  %-*s  %*d  %*.1f  %*.1f  %*.1f  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   $tot_nseq / $ribo_secs,
                $width_H{"ntsec"},    $tot_nnt  / $ribo_secs, 
                $width_H{"ntseccpu"}, ($tot_nnt  / $ribo_secs) / $ncpu, 
                $width_H{"total"},    ribo_GetTimeString($ribo_secs));
  }
     
  $stage = "sensor";
  if(opt_Get("--skipsearch", $opt_HHR)) { 
    printf $FH ("  %-*s  %*d  %*s  %*s  %*s  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   "-",
                $width_H{"ntsec"},    "-",
                $width_H{"ntseccpu"}, "-",
                $width_H{"total"},    "-");
  }
  else { 
    printf $FH ("  %-*s  %*d  %*.1f  %*.1f  %*.1f  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   $tot_nseq / $sensor_secs,
                $width_H{"ntsec"},    $tot_nnt  / $sensor_secs, 
                $width_H{"ntseccpu"}, ($tot_nnt  / $sensor_secs) / $ncpu, 
                $width_H{"total"},    ribo_GetTimeString($sensor_secs));
  }

  $stage = "total";
  if(opt_Get("--skipsearch", $opt_HHR)) { 
    printf $FH ("  %-*s  %*d  %*s  %*s  %*s  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   "-",
                $width_H{"ntsec"},    "-",
                $width_H{"ntseccpu"}, "-",
                $width_H{"total"},    ribo_GetTimeString($tot_secs));
  }
  else { 
    printf $FH ("  %-*s  %*d  %*.1f  %*.1f  %*.1f  %*s\n", 
                $width_H{"stage"},    $stage,
                $width_H{"nseq"},     $tot_nseq,
                $width_H{"seqsec"},   $tot_nseq / $tot_secs,
                $width_H{"ntsec"},    $tot_nnt  / $tot_secs, 
                $width_H{"ntseccpu"}, ($tot_nnt  / $tot_secs) / $ncpu, 
                $width_H{"total"},    ribo_GetTimeString($tot_secs));
  }

  printf $FH ("#\n");
  
  return;

}

#################################################################
# Subroutine: fetch_seqs_given_gpipe_file()
# Incept:     EPN, Tue May 16 11:38:57 2017
#
# Purpose:    Fetch sequences to a file given the gpipe output file
#             based on the sequence type.
#
# Arguments:
#   $sfetch_exec: path to esl-sfetch executable
#   $seq_file:    sequence file to fetch from 
#   $gpipe_file:  the gpipe file to parse to determine what sequences
#                 to fetch
#   $string:      string to match in column $column of sequences to fetch
#   $column:      column to look for $string in (<= 7)
#   $do_revcomp:  '1' to reverse complement minus strand sequences, '0' not to
#   $sfetch_file: the sfetch file to create for fetching purposes 
#   $subseq_file: the sequence file to create
#   $opt_HHR:     ref to 2D hash of cmdline options
#
# Returns:  Two values:
#           Number of sequences fetched.
#           Number of sequences reversed complemented as they're fetched
#           (second value will always be 0 if $do_revcomp is 0)
#
# Dies:     Never.
#
#################################################################
sub fetch_seqs_given_gpipe_file { 
  my $sub_name = "fetch_seqs_given_gpipe_file()";
  my $nargs_expected = 10;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($sfetch_exec, $seq_file, $gpipe_file, $string, $column, $do_revcomp, $sfetch_file, $subseq_file, $seqlen_HR, $opt_HHR) = (@_);

  my @el_A           = ();    # array of the space delimited tokens in a line
  my $nseq           = 0;     # number of sequences fetched
  my $nseq_revcomped = 0;     # number of sequences reversed complemented when they're fetched
  my $strand         = undef; # strand of the hit
  my $seqid          = undef; # a sequence id
  my $seqlen         = undef; # length of a sequence

  if(($column <= 0) || ($column > 7)) { 
    die "ERROR in $sub_name, invalid column: $column, should be between 1 and 7"; 
  }

  open(GPIPE,        $gpipe_file) || die "ERROR in $sub_name, unable to open $gpipe_file for reading";
  open(SFETCH, ">", $sfetch_file) || die "ERROR in $sub_name, unable to open $sfetch_file for writing";

  while(my $line = <GPIPE>) { 
    # example lines
    ##idx   sequence                                      taxonomy               strnd              type    failsto  error(s)
    ##----  --------------------------------------------  ---------------------  -----------------  ----  ---------  --------
    #1      gi|290622485|gb|GU635890.1|                   SSU.Bacteria           plus               RPSP       pass  -
    #2      gi|188039824|gb|EU677786.1|                   SSU.Bacteria           plus               RPSP       pass  -
    #3      gi|333495999|gb|JF781658.1|                   SSU.Bacteria           plus               RPSP       pass  -
    #4      gi|269165748|gb|GU035339.1|                   SSU.Bacteria           plus               RPSP       pass  -
    if($line !~ m/^\#/) { 
      @el_A = split(/\s+/, $line);
      if($el_A[($column-1)] =~ m/$string/) { 
        # format of sfetch line: <newname> <start> <end> <sourcename>
        $seqid  = $el_A[1];
        if(! exists $seqlen_HR->{$seqid}) { 
          die "ERROR in $sub_name, no length information for sequence $seqid";
        }
        $seqlen = $seqlen_HR->{$seqid};

        if($do_revcomp) { 
          # determine if sequence is minus strand:
          $strand = determine_strand_given_gpipe_strand($el_A[3], $el_A[4]);
          if($strand eq "minus") { 
            printf SFETCH ("$seqid  $seqlen 1 $seqid\n");
            $nseq_revcomped++;
          }
          else { # not minus strand
            printf SFETCH ("$seqid  1 $seqlen $seqid\n");
          }
        }
        else { # ! $do_revcomp
          printf SFETCH ("$seqid\n");
        }
        $nseq++;
      }
    }
  }
  close(GPIPE);
  close(SFETCH);

  if($nseq > 0) { 
    my $sfetch_cmd;
    if($do_revcomp) { 
      $sfetch_cmd = $sfetch_exec . " -Cf $seq_file $sfetch_file > $subseq_file"; 
    }
    else { 
      $sfetch_cmd = $sfetch_exec . " -f $seq_file $sfetch_file > $subseq_file"; 
    }
    ribo_RunCommand($sfetch_cmd, opt_Get("-v", $opt_HHR));
  }

  return ($nseq, $nseq_revcomped);
}

#################################################################
# Subroutine: determine_strand_given_gpipe_strand()
# Incept:     EPN, Tue May 16 15:30:53 2017
#
# Purpose:    Given the strand field for a sequence from the GPIPE file,
#             determine if it is 'minus' or 'plus' strand. 
#
# Arguments:
#   $strand:      <s> = 'plus', 'minus', 'NA', or 'mixed', OR <s>(S):<s>(R)
#                 for <s>, we just return <s>, for <s1>(S):<s2>(R) we return
#                 <s2> if ribotyper passed (determine from $type string)
#                 and we return <s1> if ribotyper failed and ribotyper passed
#   $type:        'RPSP', 'RPSF', 'RFSP', /RFSF'
#
# Returns:  Nothing.
# 
# Dies:     Never.
#
#################################################################
sub determine_strand_given_gpipe_strand { 
  my $sub_name = "determine_strand_given_gpipe_strand()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my $rstrand = undef; # strand predicted by ribotyper
  my $sstrand = undef; # strand predicted by sensor

  my ($strand, $type) = (@_);

  if(($strand eq "plus")   || 
     ($strand eq "minus")  || 
     ($strand eq "NA")     || 
     ($strand eq "mixed")) { 
    return $strand;
  }
  elsif($strand =~ /^(\S+)\(S\)(\S+)\(R\)$/) { 
    ($sstrand, $rstrand) = ($1, $2);
    if($type eq "RPSP" || $type eq "RPSF") { 
      return $rstrand;
    }
    elsif($type eq "RFSP") { 
      return $sstrand;
    }
    elsif($type eq "RFSF") { 
      return $strand; # return full string
    }
    else { 
      die "ERROR in $sub_name, unexpected type: $type";
    }
  }
  else { 
    die "ERROR in $sub_name, unable to parse strand value: $strand";
  }

  return; # never reached
}
