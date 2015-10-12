# edgeR has the normalisation function(s)
library("edgeR", lib.loc="~/R/x86_64-pc-linux-gnu-library/3.0")

setwd("/usr/users/cbr/couchman/xiao_share/Matthew_Couchman/RNAseq_analysis")

# list of feature count files to process
count_files <- c(
  "d1d2spm.accepted_hits.StartOnly.w50.featureCounts",
  "d1d2veg.accepted_hits.StartOnly.w50.featureCounts",
  "WTmeiocyte.accepted_hits.StartOnly.w50.featureCounts",
  "WTRootAZRep1.accepted_hits.StartOnly.w50.featureCounts"
)

# list of experiments that feature counts are associated with
groups <- c("d1d2", "d1d2", "WT", "WT")
# create data frame with files together with their experiment name
fg <- data.frame(files=count_files, group=groups)
# list of labels to apply to data
labels <- c("d1d2spm", "d1d2veg", "WTmeiocyte", "WTRootAZRep1")

### edgeR stuff ###
# collate the separate gene count files
dge <- readDGE(fg, labels=labels, header=FALSE)
# estimate dispersion 
dge <- estimateCommonDisp(dge)
# estimate tag specific dispersion
dge <- estimateTagwiseDisp(dge)


