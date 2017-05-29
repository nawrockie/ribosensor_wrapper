Ribosensor v0.05 README

Organization of this file:

INTRO
SETTING UP ENVIRONMENT VARIABLES
WHAT RIBOSENSOR DOES
SAMPLE RUN
OUTPUT
EXPLANATION OF ERRORS
ALL COMMAND LINE OPTIONS
GETTING MORE INFORMATION

##############################################################################
INTRO

This is documentation for ribosensor, a tool for detecting and
classifying SSU rRNA and LSU rRNA sequences that uses profile HMMs and
BLASTN.

Authors: Eric Nawrocki and Alejandro Scaffer

Current location of code and other relevant files:
/panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper/

The initial setup of ribosensor is intended for internal NCBI usage in
evaluating submissions. It is expected that ribosensor will be
incorporated into the internal NCBI software architecture called
gpipe. Therefore, at this time, some of the documentation is on
internal Confluence pages and some of the error reporting is
structured in a manner that conforms to established gpipe practices
for error reporting.


##############################################################################
SETTING UP ENVIRONMENT VARIABLES

Before running ribosensor.pl you will need to update some of your
environment variables. To do this, add the following seven lines to
either the file .bashrc (if you use bash shell) or the file .cshrc
file (if you use C shell or tcsh). The .bashrc or .cshrc file will be
in your home directory. To determine what shell you use, enter the
command 'echo $SHELL' If this command returns '/bin/bash', then update
the file .bashrc.  If this command returns '/bin/csh' or '/bin/tcsh',
then update your .cshrc file.

Before updating the pertinent shell file, it is necessary to know
whether the environment variable PERL5LIB is already defined or
not. To determine this information, enter the command echo $PERL5LIB
If this command returns one or more directories, then PERL5LIB is
already defined.

The seven lines to add to the file .bashrc, if PERL5LIB is already defined:
-----------
export RIBOSENSORDIR="/panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper"
export EPNOPTDIR="/panfs/pan1/dnaorg/ssudetection/code/epn-options"
export RIBODIR="/panfs/pan1/dnaorg/ssudetection/code/ribotyper-v1"
export SENSORDIR="/panfs/pan1/dnaorg/ssudetection/code/16S_sensor"
export PERL5LIB="$RIBODIR:$EPNOPTDIR:$PERL5LIB"
export PATH="$RIBOSENSORDIR:$PATH"
export BLASTDB="$SENSORDIR:$BLASTDB"
-----------

The seven lines to add to the file .cshrc, if PERL5LIB is already defined:
-----------
setenv RIBOSENSORDIR "/panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper"
setenv RIBODIR "/panfs/pan1/dnaorg/ssudetection/code/ribotyper-v1"
setenv SENSORDIR "/panfs/pan1/dnaorg/ssudetection/code/16S_sensor"
setenv EPNOPTDIR "/panfs/pan1/dnaorg/ssudetection/code/epn-options"
setenv PERL5LIB "$RIBODIR":"$EPNOPTDIR":"$PERL5LIB"
setenv PATH "$RIBOSENSORDIR":"$PATH"
setenv BLASTDB "$SENSORDIR":"$BLASTDB"
-----------

If PERL5LIB was not already defined, use instead
export PERL5LIB="$RIBODIR:$EPNOPTDIR"
for .bashrc, OR
setenv PERL5LIB "$RIBODIR":"$EPNOPTDIR"
for .cshrc.
at line 5 out of 7. 

After adding the appropriate seven lines to the appropriate shell file, execute this command:
source ~/.bashrc
OR
source ~/.cshrc

To check that your environment variables have been properly adjusted, try the
following commands:
Command 1. 
'echo $RIBOSENSORDIR'
This should return only
/panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper

Command 2. 
'echo $RIBODIR'
This should return only
/panfs/pan1/dnaorg/ssudetection/code/ribotyper-v1

Command 3. 
'echo $SENSORDIR'
This should return only
/panfs/pan1/dnaorg/ssudetection/code/16S_sensor

Command 3. 
'echo $EPNOPTDIR'
This should return only
/panfs/pan1/dnaorg/ssudetection/code/epn-options

Command 4. 
'echo $PERL5LIB'
This should return a (potentially longer) string that begins with 
/panfs/pan1/dnaorg/ssudetection/code/ribotyper-v1:/panfs/pan1/dnaorg/ssudetection/code/epn-options

Command 5.
'echo $PATH'
This should return a (potentially longer) string that includes:
/panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper
AND
/panfs/pan1/dnaorg/ssudetection/code/16S_sensor

Command 6.
'echo $BLASTDB'
This should return a (potentially longer) string that includes:
/panfs/pan1/dnaorg/ssudetection/code/16S_sensor

If any of these commands do not return what they are supposed to,
please email Eric Nawrocki (nawrocke@ncbi.nlm.nih.gov).
If you do see the expected output, then the sample run below (in the section
SAMPLE RUN) should work as described below.

##############################################################################
WHAT RIBOSENSOR DOES

Ribosensor is a wrapper program that calls two other programs:
ribotyper and 16S_sensor (henceforth called 'sensor') and combines
their output together. Ribotyper uses profile HMMs to identify and
classify small subunit (SSU) ribosomal rRNA sequences (archaeal,
bacterial, eukaryotic) and large subunit ribosomal rRNA
sequences. Sensor uses BLASTN to identify bacterial and archaeal 16S
SSU rRNA sequences using a library of type strain archaeal and
bacterial 16S sequences.  Based on the output of both programs,
ribosensor decides if each input sequence "passes" or "fails". The
intent is that sequences that pass should be accepted for submission
to GenBank as archaeal or bacterial 16S SSU rRNA sequences, and
sequences that fail should not.

For sequences that fail, reasons for failure are reported in the form
of sensor, ribotyper, and/or GPIPE errors. These errors and their
relationship are described in the section EXPLANATION OF ERRORS,
below. The present structure of handling submissions in gpipe encodes
the principle that some errors are more serious and basic and "fail to
the submitter" who is expected to make repairs before trying to revise
the GenBank submission. Other errors "fail to an indexer", meaning
that the GenBank indexer handling the submission is expected to make
the repairs or to do further in-house evaluation of the sequence
before returning it to the submitter.

For more information on ribotyper, see its 00README.txt:
https://github.com/nawrockie/ribotyper-v1/blob/master/00README.txt

For more information on 16S_sensor, see its README: 
https://github.com/aaschaffer/16S_sensor/blob/master/README

##############################################################################
SAMPLE RUN

This example runs the script on a sample file of 16 sequences. Go into
a new directory and execute:

ribosensor.pl $RIBOSENSORDIR/testfiles/seed-15.fa test

The script ribosensor.pl takes two command line arguments:

The first argument is the sequence file to annotate.

The second argument is the name of the output subdirectory that
ribotyper should create. Output files will be placed in this output
directory. If this directory already exists, the program will exit
with an error message indicating that you need to either (a) remove
the directory before rerunning, or (b) use the -f option with
ribotyper.pl, in which case the directory will be overwritten.

The $RIBOSENSORDIR environment variable is used here. That is
a hard-coded path that was set in the 'SETTING UP ENVIRONMENT
VARIABLES:' section above. 

##############################################################################
OUTPUT

Example output of the script from the above command
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ribosensor.pl :: analyze ribosomal RNA sequences with profile HMMs and BLASTN
# ribosensor 0.05 (May 2017)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:    Fri May 26 09:45:18 2017
#
# target sequence input file:   /panfs/pan1/dnaorg/ssudetection/code/ribosensor_wrapper/testfiles/seed-15.fa
# output directory name:        test
# forcing directory overwrite:  yes [-f]
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Partitioning sequence file based on sequence lengths  ... done. [0.1 seconds]
# Running ribotyper on full sequence file               ... done. [3.3 seconds]
# Running 16S-sensor on seqs of length 351..600         ... done. [0.2 seconds]
# Running 16S-sensor on seqs of length 601..inf         ... done. [1.7 seconds]
# Parsing and combining 16S-sensor and ribotyper output ... done. [0.0 seconds]
#
# Outcome counts:
#
# type   total  pass  indexer  submitter  unmapped
# -----  -----  ----  -------  ---------  --------
  RPSP       8     8        0          0         0
  RPSF       1     0        1          0         0
  RFSP       0     0        0          0         0
  RFSF       7     0        3          4         0
#
  *all*     16     8        4          4         0
#
# Per-program error counts:
#
#                      number   fraction
# error                of seqs   of seqs
# -------------------  -------  --------
  CLEAN                      8   0.50000
  S_NoHits                   1   0.06250
  S_TooLong                  1   0.06250
  S_LowScore                 5   0.31250
  S_BothStrands              1   0.06250
  S_MultipleHits             4   0.25000
  S_LowSimilarity            5   0.31250
  R_NoHits                   1   0.06250
  R_UnacceptableModel        5   0.31250
  R_LowCoverage              1   0.06250
#
#
# GPIPE error counts:
#
#                           number   fraction
# error                     of seqs   of seqs
# ------------------------  -------  --------
  CLEAN                           8   0.50000
  SEQ_HOM_Not16SrRNA              1   0.06250
  SEQ_HOM_LowSimilarity           5   0.31250
  SEQ_HOM_LengthLong              1   0.06250
  SEQ_HOM_MisAsBothStrands        1   0.06250
  SEQ_HOM_TaxNotArcBacChl         5   0.31250
  SEQ_HOM_LowCoverage             1   0.06250
  SEQ_HOM_MultipleHits            4   0.25000
#
#
# Timing statistics:
#
# stage      num seqs  seq/sec      nt/sec  nt/sec/cpu  total time             
# ---------  --------  -------  ----------  ----------  -----------------------
  ribotyper        16      4.7      6302.6      6302.6  00:00:03.37  (hh:mm:ss)
  sensor           16      7.2      9604.5      9604.5  00:00:02.21  (hh:mm:ss)
  total            16      2.8      3714.9      3714.9  00:00:05.72  (hh:mm:ss)
#
#
#
# Human readable error-based output saved to file test/test.ribosensor.out
# GPIPE error-based output saved to file test/test.ribosensor.gpipe
#
#[RIBO-SUCCESS]

-----------------
Output files:

Currently, there are two output files. Both are tabular output files
with one line per sequence with fields separated by whitespace (spaces,
not tabs). They will both be in the new directory 'test' that was
created by the example run above.

The first file type is a 'human readable error-based' output file,
and includes the errors reported from both ribotyper and sensor.
An example is below.

Human readable file:
$ cat testfiles/test.ribosensor.out 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#idx  sequence                                       taxonomy               strand             type    failsto  error(s)
#---  ---------------------------------------------  ---------------------  -----------------  ----  ---------  --------
1     00052::Halobacterium_sp.::AE005128             SSU.Archaea            plus               RPSP       pass  -
2     00013::Methanobacterium_formicicum::M36508     SSU.Archaea            plus               RPSP       pass  -
3     00004::Nanoarchaeum_equitans::AJ318041         SSU.Archaea            mixed(S):plus(R)   RPSF    indexer  S_LowScore;S_BothStrands;S_MultipleHits;
4     00121::Thermococcus_celer::M21529              SSU.Archaea            plus               RFSF  submitter  S_LowSimilarity;R_LowCoverage:(0.835<0.880);
5     random                                         -                      NA                 RFSF  submitter  S_NoHits;R_NoHits;
6     00115::Pyrococcus_furiosus::U20163|g643670     SSU.Archaea            minus              RPSP       pass  -
7     00035::Bacteroides_fragilis::M61006|g143965    SSU.Bacteria           plus               RPSP       pass  -
8     01106::Bacillus_subtilis::K00637               SSU.Bacteria           plus               RPSP       pass  -
9     00072::Chlamydia_trachomatis.::AE001345        SSU.Bacteria           plus               RPSP       pass  -
10    01351::Mycoplasma_gallisepticum::M22441        SSU.Bacteria           minus              RPSP       pass  -
11    00224::Rickettsia_prowazekii.::AJ235272        SSU.Bacteria           plus               RPSP       pass  -
12    01223::Audouinella_hermannii.::AF026040        SSU.Eukarya            plus               RFSF    indexer  S_LowScore;S_MultipleHits;S_LowSimilarity;R_UnacceptableModel:(SSU_rRNA_eukarya);
13    01240::Batrachospermum_gelatinosum.::AF026045  SSU.Eukarya            plus               RFSF    indexer  S_LowScore;S_MultipleHits;S_LowSimilarity;R_UnacceptableModel:(SSU_rRNA_eukarya);
14    00220::Euplotes_aediculatus.::M14590           SSU.Eukarya            plus               RFSF    indexer  S_LowScore;S_MultipleHits;S_LowSimilarity;R_UnacceptableModel:(SSU_rRNA_eukarya);
15    00229::Oxytricha_granulifera.::AF164122        SSU.Eukarya            minus              RFSF  submitter  S_LowScore;S_LowSimilarity;R_UnacceptableModel:(SSU_rRNA_eukarya);
16    01710::Oryza_sativa.::X00755                   SSU.Eukarya            plus               RFSF  submitter  S_TooLong;R_UnacceptableModel:(SSU_rRNA_eukarya);
#
# Explanation of columns:
#
# Column 1 [idx]:      index of sequence in input sequence file
# Column 2 [target]:   name of target sequence
# Column 3 [taxonomy]: inferred taxonomy of sequence
# Column 4 [strnd]:    strand ('plus' or 'minus') of best-scoring hit
# Column 5 [type]:     "R<1>S<2>" <1> is 'P' if passes ribotyper, 'F' if fails; <2> is same, but for sensor
# Column 6 [failsto]:  'pass' if sequence passes
#                      'indexer'   to fail to indexer
#                      'submitter' to fail to submitter
#                      '?' if situation is not covered in the code
# Column 7 [error(s)]: reason(s) for failure (see 00README.txt)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The second file type is a 'GPIPE error-based' output file. It includes
much of the same information as the human readable file, with the main
difference being that the ribotyper and sensor errors have been
replaced with their corresponding 'GPIPE' errors.
An example is below.

GPIPE output file
$ cat testfiles/test.ribosensor.gpipe
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#idx  sequence                                       taxonomy               strand              p/f  error(s)
#---  ---------------------------------------------  ---------------------  -----------------  ----  --------
1     00052::Halobacterium_sp.::AE005128             SSU.Archaea            plus               RPSP  -
2     00013::Methanobacterium_formicicum::M36508     SSU.Archaea            plus               RPSP  -
3     00004::Nanoarchaeum_equitans::AJ318041         SSU.Archaea            mixed(S):plus(R)   RPSF  SEQ_HOM_MisAsBothStrands;SEQ_HOM_MultipleHits;
4     00121::Thermococcus_celer::M21529              SSU.Archaea            plus               RFSF  SEQ_HOM_LowSimilarity;SEQ_HOM_LowCoverage;
5     random                                         -                      NA                 RFSF  SEQ_HOM_Not16SrRNA;
6     00115::Pyrococcus_furiosus::U20163|g643670     SSU.Archaea            minus              RPSP  -
7     00035::Bacteroides_fragilis::M61006|g143965    SSU.Bacteria           plus               RPSP  -
8     01106::Bacillus_subtilis::K00637               SSU.Bacteria           plus               RPSP  -
9     00072::Chlamydia_trachomatis.::AE001345        SSU.Bacteria           plus               RPSP  -
10    01351::Mycoplasma_gallisepticum::M22441        SSU.Bacteria           minus              RPSP  -
11    00224::Rickettsia_prowazekii.::AJ235272        SSU.Bacteria           plus               RPSP  -
12    01223::Audouinella_hermannii.::AF026040        SSU.Eukarya            plus               RFSF  SEQ_HOM_LowSimilarity;SEQ_HOM_TaxNotArcBacChl;SEQ_HOM_MultipleHits;
13    01240::Batrachospermum_gelatinosum.::AF026045  SSU.Eukarya            plus               RFSF  SEQ_HOM_LowSimilarity;SEQ_HOM_TaxNotArcBacChl;SEQ_HOM_MultipleHits;
14    00220::Euplotes_aediculatus.::M14590           SSU.Eukarya            plus               RFSF  SEQ_HOM_LowSimilarity;SEQ_HOM_TaxNotArcBacChl;SEQ_HOM_MultipleHits;
15    00229::Oxytricha_granulifera.::AF164122        SSU.Eukarya            minus              RFSF  SEQ_HOM_LowSimilarity;SEQ_HOM_TaxNotArcBacChl;
16    01710::Oryza_sativa.::X00755                   SSU.Eukarya            plus               RFSF  SEQ_HOM_LengthLong;SEQ_HOM_TaxNotArcBacChl;
#
# Explanation of columns:
#
# Column 1 [idx]:      index of sequence in input sequence file
# Column 2 [target]:   name of target sequence
# Column 3 [taxonomy]: inferred taxonomy of sequence
# Column 4 [strnd]:    strand ('plus' or 'minus') of best-scoring hit
# Column 5 [type]:     "R<1>S<2>" <1> is 'P' if passes ribotyper, 'F' if fails; <2> is same, but for sensor
# Column 6 [error(s)]: reason(s) for failure (see 00README.txt)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

##############################################################################
EXPLANATION OF ERRORS

(The text and tables below were taken from
https://confluence.ncbi.nlm.nih.gov/display/GEN/Ribosensor%3A+proposed+criteria+and+names+for+errors
on May 26, 2017)

List of Sensor and Ribotyper errors (listed in Ribosensor 'human
readable output file'):

---------
                                                   ignored if
     Ribotyper (R_) or                             RPSF and
idx  Sensor (S_) error   associated GPIPE error    uncultued    cause/explanation
---  -----------------   ------------------------  ----------   ------------------------------------
S1.  S_NoHits            SEQ_HOM_Not16SrRNA        yes          no hits reported ('no' column 2)
S2.  S_NoSimilarity      SEQ_HOM_LowSimilarity     yes          coverage (column 5) of best blast hit is < 10%
S3.  S_LowSimilarity     SEQ_HOM_LowSimilarity     yes          coverage (column 5) of best blast hit is < 80%
                                                                (<=350nt) or 86% (>350nt)
S4.  S_LowScore          SEQ_HOM_LowSimilarity     yes          either id percentage below length dependent threshold (75,80,86)
                                                                OR E-value above 1e-40 ('imperfect_match' column 2)
S5.  S_BothStrands       SEQ_HOM_MisAsBothStrands  no           hits on both strands ('mixed' column 2)
S6.  S_MultipleHits      SEQ_HOM_MultipleHits      no           more than 1 hit reported (column 4 > 1)
------------------------------------------------------------------------------------------------------------------------------
R1.  R_NoHits            SEQ_HOM_Not16SrRNA        N/A          no hits reported
R2.  R_MultipleFamilies  SEQ_HOM_16SAnd23SrRNA     N/A          SSU and LSU hits
R3.  R_LowScore          SEQ_HOM_LowSimilarity     N/A          bits/position score is < 0.5
R4.  R_BothStrands       SEQ_HOM_MisAsBothStrands  N/A          hits on both strands
R5.  R_InconsistentHits  SEQ_HOM_MisAsHitOrder     N/A          hits are in different order in sequence and model
R6.  R_DuplicateRegion   SEQ_HOM_MisAsDupRegion    N/A          hits overlap by 10 or more model positions
R7.  R_UnacceptableModel SEQ_HOM_TaxNotArcBacChl   N/A          best hit is to model other than SSU.Archaea, SSU.Bacteria,
                                                                SSU.Cyanobacteria, or SSU.Chloroplast
R8.  R_QuestionableModel SEQ_HOM_TaxChloroplast    N/A          best hit is to SSU.Chloroplast
R9.  R_LowCoverage       SEQ_HOM_LowCoverage       N/A          coverage of all hits is < 0.88
R10. R_MultipleHits      SEQ_HOM_MultipleHits      N/A          more than 1 hit reported
---------

The following list of GPIPE errors (listed in Ribosensor 'GPIPE output file') is relevant in the expected gpipe
usage. One possible difference is that each sequence may be assigned one or more errrors, but gpipe determines
whether an entire submission (typically comprising multiple sequences) succeeds or fails. At present, a submission
fails if any of the sequences in the submission fails.

---------
idx  GPIPE error               fails to      triggering Sensor/Ribotyper errors
---  ------------------------- ---------     ----------------------------------
G1.  SEQ_HOM_Not16SrRNA        submitter     S_NoHits*, R_NoHits
G2.  SEQ_HOM_LowSimilarity     submitter     S_NoSimilarity*, S_LowSimilarity*, S_LowScore*, R_LowScore
G3.  SEQ_HOM_16SAnd23SrRNA     submitter     R_MultipleFamilies
G4.  SEQ_HOM_MisAsBothStrands  submitter     S_BothStrands, R_BothStrands
G5.  SEQ_HOM_MisAsHitOrder     submitter     R_InconsistentHits
G6.  SEQ_HOM_MisAsDupRegion    submitter     R_DuplicateRegion
G7.  SEQ_HOM_TaxNotArcBacChl   submitter     R_UnacceptableModel
G8.  SEQ_HOM_TaxChloroplast    indexer       R_QuestionableModel
G9.  SEQ_HOM_LowCoverage       indexer       R_LowCoverage
G10. SEQ_HOM_MultipleHits      indexer       S_MultipleHits, R_MultipleHits

* these Sensor errors do not trigger a GPIPE error if sequence is 'RPSF'
  (ribotyper pass, sensor fail) and sample is uncultured (-c option not
  used with ribosensor_wrapper.pl).
---------

For more information on ribotyper errors which are reported prefixed
with 'R_' in column 7 of the human readable output file, see
ribotyper's 00README.txt:
https://github.com/nawrockie/ribotyper-v1/blob/master/00README.txt

For more information on sensor errors which are reported prefixed with
'S_' in column 7 of the human readable output file, see sensor's
README file:
https://github.com/aaschaffer/16S_sensor/blob/master/README


A few important points about the lists of errors above:

- A GPIPE error is triggered by one or more occurrences of its
  triggering Sensor/Ribotyper errors (with the exception listed above
  for '*').

- This definition of Sensor/Ribotyper errors and the GPIPE errors they
  trigger is slightly different from the most recent Confluence
  'Analysis3-20170515' word document. Eric made changes where he thought
  it made sense with the following goals in mind:

  A) simplifying the 'Outcomes' section of the Analysis document,
  which explained how to determine whether sequences pass or fail to
  submitter or fail to indexer based on the ribotyper and sensor
  output.  
  
  B) reporting GPIPE errors in the format that Alex Kotliarov asked for
  at the May 15 meeting.

##############################################################################
ALL COMMAND LINE OPTIONS

To see all the available command-line options to ribosensor.pl, call
it with the -h option:

# ribosensor.pl :: analyze ribosomal RNA sequences with profile HMMs and BLASTN
# ribosensor 0.05 (May 2017)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# date:    Fri May 26 10:20:39 2017
#
Usage: ribosensor.pl [-options] <fasta file to annotate> <output directory>


basic options:
  -f           : force; if <output directory> exists, overwrite it
  -c           : assert sequences are from cultured organisms
  -n <n>       : use <n> CPUs [0]
  -v           : be verbose; output commands to stdout as they're run
  --keep       : keep all intermediate files that are removed by default
  --skipsearch : skip search stages, use results from earlier run

16S_sensor related options:
  --Sminlen <n>    : set 16S_sensor minimum sequence length to <n> [100]
  --Smaxlen <n>    : set 16S_sensor minimum sequence length to <n> [2000]
  --Smaxevalue <x> : set 16S_sensor maximum E-value to <x> [1e-40]
  --Sminid1 <n>    : set 16S_sensor minimum percent id for seqs <= 350 nt to <n> [75]
  --Sminid2 <n>    : set 16S_sensor minimum percent id for seqs [351..600] nt to <n> [80]
  --Sminid3 <n>    : set 16S_sensor minimum percent id for seqs > 600 nt to <n> [86]
  --Smincovall <n> : set 16S_sensor minimum coverage for all sequences to <n> [10]
  --Smincov1 <n>   : set 16S_sensor minimum coverage for seqs <= 350 nt to <n> [80]
  --Smincov2 <n>   : set 16S_sensor minimum coverage for seqs  > 350 nt to <n> [86]

options for saving sequence subsets to files:
  --psave : save passing sequences to a file

##############################################################################
GETTING MORE INFORMATION

Both ribotyper and 16S_sensor have their own README files, with
additional information about those programs and their outputs:

https://github.com/nawrockie/ribotyper-v1/blob/master/00README.txt
https://github.com/aaschaffer/16S_sensor/blob/master/README

--------------------------------------

Last updated: AAS, Fri May 26 18:05:00 2017

--------------------------------------
