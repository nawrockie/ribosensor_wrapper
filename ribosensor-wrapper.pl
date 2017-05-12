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
opt_Add("--keep",        "boolean", 0,                       1,    undef, undef,      "keep all intermediate files",                    "keep all intermediate files that are removed by default", \%opt_HH, \@opt_order_A);
#opt_Add("-i",           "string",  undef,                    1,    undef, undef,      "use model info file <s> instead of default",     "use model info file <s> instead of default", \%opt_HH, \@opt_order_A);

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
                'keep'         => \$GetOptions_H{"--keep"});

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
my $progress_w = 48; # the width of the left hand column in our progress output, hard-coded
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

# 
my $seqstat_file = $out_root . ".seqstat";
if(! opt_Get("--keep", \%opt_HH)) { 
  push(@to_remove_A, $seqstat_file);
}
ribo_ProcessSequenceFile($execs_H{"esl-seqstat"}, $seq_file, $seqstat_file, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH);

exit;
