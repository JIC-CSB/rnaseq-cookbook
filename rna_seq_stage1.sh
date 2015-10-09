#!/usr/bin/env bash
#
#BSUB -q testing
#BSUB -J RNASeq-stage1
#BSUB -R "rusage[mem=100000]"

read -r -d '' USAGE << EOM
usage: `basename $0` input_file_r1 -i input_file_r2 output_directory
EOM

R1_INPUT_FILE=$1
R2_INPUT_FILE=$2
OUTPUT_DIR=$3

GENOME_DIR=~/Genome


# Make sure that the R1 input file exists.
if [ ! -e "$R1_INPUT_FILE" ]; then
  echo "No such file: $R1_INPUT_FILE" >&2
  echo "" >&2
  echo "$USAGE" >&2
  exit 2
fi

# Make sure that the R2 input file exists.
if [ ! -e "$R2_INPUT_FILE" ]; then
  echo "No such file: $R2_INPUT_FILE" >&2
  echo "" >&2
  echo "$USAGE" >&2
  exit 2
fi

# Create the output directory if it does not exist.
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir $OUTPUT_DIR
fi


#############################################################################
# Define some helper functions.
#############################################################################
function base_fname () {
    echo ${1##*/}
}

function unzip_fname () {
    local fname
    fname=$(base_fname $1)
    echo ${fname%.*}
}

function log_and_run {
  echo $@
  $@
}


#############################################################################
# Copy the input file into the output directory and unzip it.
#############################################################################
log_and_run cp $R1_INPUT_FILE $OUTPUT_DIR
log_and_run gunzip "$OUTPUT_DIR/$(base_fname $R1_INPUT_FILE)"
FASTQC_FILE=$OUTPUT_DIR/$(unzip_fname $R1_INPUT_FILE)


#############################################################################
# Run fastqc analysis.
#############################################################################
log_and_run source fastqc-0.10.1
log_and_run fastqc -f fastq -o $OUTPUT_DIR $FASTQC_FILE


#############################################################################
# Trim the data.
#############################################################################
log_and_run source jdk-7u45
log_and_run source trimmomatic-0.33

# Create the trimmomatic output directory if it does not exist.
TRIMMOMATIC_DIR=$OUTPUT_DIR/trimmomatic
if [ ! -d "$TRIMMOMATIC_DIR" ]; then
  log_and_run mkdir $TRIMMOMATIC_DIR
fi

for strand in $R1_INPUT_FILE $R2_INPUT_FILE
do
    log_and_run java -jar /nbi/software/testing/trimmomatic/0.33/x86_64/bin/trimmomatic-0.33.jar SE -phred33 $strand $TRIMMOMATIC_DIR/$(unzip_fname $strand) ILLUMINACLIP:TruSeq-PE:2:30:10 LEADING:3 SLIDINGWINDOW:4:15 MINLEN:36
done


#############################################################################
# Align the data.
#############################################################################
log_and_run source tophat-2.0.10

# Create the tophat output directory if it does not exist.
TOPHAT_DIR=$OUTPUT_DIR/tophat
if [ ! -d "$TOPHAT_DIR" ]; then
  log_and_run mkdir $TOPHAT_DIR
fi

log_and_run tophat -p 64 -I 1000 -r 100 -o $TOPHAT_DIR $GENOME_DIR/Tomato.dna $TRIMMOMATIC_DIR/$(unzip_fname $R1_INPUT_FILE) $TRIMMOMATIC_DIR/$(unzip_fname $R2_INPUT_FILE)


#############################################################################
# Sort the Bam file.
#############################################################################
log_and_run source samtools-0.1.19
log_and_run source bedtools-2.17.0

log_and_run samtools sort $TOPHAT_DIR/accepted_hits.bam $TOPHAT_DIR/accepted_hits.sorted.bam
log_and_run samtools flagstat $TOPHAT_DIR/accepted_hits.sorted.bam > $TOPHAT_DIR/T0A_stats.txt
log_and_run samtools index $TOPHAT_DIR/accepted_hits.bam $TOPHAT_DIR/T0A_accepted_hits.sorted.bai
log_and_run genomeCoverageBed -bg -ibam $TOPHAT_DIR/accepted_hits.sorted.bam -g $GENOME_DIR/Tomato.genome > $TOPHAT_DIR/accepted_hits.bedgraph

#############################################################################
# Isoform expression and transcriptome assembly.
#############################################################################
log_and_run source cufflinks-2.2.1

# Create the cufflinks output directory if it does not exist.
CUFFLINKS_DIR=$OUTPUT_DIR/cufflinks

if [ ! -d "$CUFFLINKS_DIR" ]; then
  log_and_run mkdir $CUFFLINKS_DIR
fi

log_and_run cufflinks -o $CUFFLINKS_DIR -G $GENOME_DIR/Tomato_assembly.gtf -p 8 -b $GENOME_DIR/Tomato.dna.fasta -u --library-type fr-unstranded $TOPHAT_DIR/accepted_hits.bam
