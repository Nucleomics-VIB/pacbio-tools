#!/bin/bash

# script: kinnex_bc-pairs.sh
# produce all pairwise combinations between primers of Kinnex 16S
# plates-A and B

# First list of strings
list1=(
  "Kinnex16S_Fwd_01"
  "Kinnex16S_Fwd_02"
  "Kinnex16S_Fwd_03"
  "Kinnex16S_Fwd_04"
  "Kinnex16S_Fwd_05"
  "Kinnex16S_Fwd_06"
  "Kinnex16S_Fwd_07"
  "Kinnex16S_Fwd_08"
  "Kinnex16S_Fwd_09"
  "Kinnex16S_Fwd_10"
  "Kinnex16S_Fwd_11"
  "Kinnex16S_Fwd_12"
)

# plate A
list2=(
  "Kinnex16S_Rev_13"
  "Kinnex16S_Rev_14"
  "Kinnex16S_Rev_15"
  "Kinnex16S_Rev_16"
  "Kinnex16S_Rev_17"
  "Kinnex16S_Rev_18"
  "Kinnex16S_Rev_19"
  "Kinnex16S_Rev_20"
)

# plate B
list3=(
  "Kinnex16S_Rev_21"
  "Kinnex16S_Rev_22"
  "Kinnex16S_Rev_23"
  "Kinnex16S_Rev_24"
  "Kinnex16S_Rev_25"
  "Kinnex16S_Rev_26"
  "Kinnex16S_Rev_27"
  "Kinnex16S_Rev_28"
)

# Header
echo "Barcode,Bio Sample"

# Loop through each item in list1 and pair it with each item in list2
smplnum=0
for i in "${list1[@]}"; do
  for j in "${list2[@]}"; do
    ((smplnum++))
    echo "$i--$j,sample_${smplnum}"
  done
done

for i in "${list1[@]}"; do
  for j in "${list3[@]}"; do
    ((smplnum++))
    echo "$i--$j,sample_${smplnum}"
  done
done