#!/usr/bin/env Rscript

# RenameTreeTip.R
# rename tree tip labels to genus.species
# Stephane Plaisance - VIB-NC Dec-22-2022 v1.0

# libraries to substitute strings and to read phylo trees
library("tidyr")
library("ape")

# load taxonomy results to get FeatureIDs and corresponding Taxon classifications
best_taxonomy_withDB <- read.delim("best_taxonomy.tsv")

# remove leading strings ?__
data <- as.data.frame(apply(best_taxonomy_withDB, 2, function(x) gsub(".__","",x)))

# split Taxon into 7 columns
data <- separate(data = data, 
         col = Taxon, into = c("kingdom", "phylum", "class", "order", "family", "genus", "species"),
         sep = ";")

# retain genus and species to shorten labels in new columns
#data$label <- paste0(data$genus, ".", data$species, sep="")
data$label <- data$species

# read ori tree file
phy <- read.tree(file = "phylogeny_diversity/phylotree_mafft_rooted.nwk")

# substitute tip.label with new shorter label
phy$tip.label <- unlist(lapply(phy$tip.label, function(x) data$label[match(x, data$Feature.ID)]))

# save to new tree file
write.tree(file="phylogeny_diversity/renamed_phylotree_mafft_rooted.nwk", phy=phy)