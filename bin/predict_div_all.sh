#!/bin/bash

BASEDIR="$(dirname $0)/.."
mkdir -p $BASEDIR/results
cd $BASEDIR/results

# Iterate over combinations of cells and cuts
echo "" > all_cells_points.txt
for FE in $(ls $BASEDIR/data/*-30.fe); do
    for START in $(cat $BASEDIR/etc/61points.txt | sed 's/\s//g'); do
         echo $FE $START >> all_cells_points.txt
    done
done

# Split up file in batches of 5000, since that is the max number of queued jobs allowed on Biocluster
rm -f split_cells_points_*
split -l 5000 all_cells_points.txt split_cells_points_ --additional-suffix='.txt'

# Gather split files
FILES=$(ls split_cells_points_*.txt)

# Submit jobs based on cell and point combinations
for FILE in ${FILES}; do
    IFS=$'\n'
    for line in $(cat ${FILE}); do
        echo predict_div.sh ${line} #| qsub -l walltime=48:00:00
    done
    # Only submit 1 file of 5000 jobs
    exit
    IFS=$' '
done
