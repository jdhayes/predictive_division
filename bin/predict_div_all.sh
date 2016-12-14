#!/bin/bash

BASEDIR="$(dirname $0)/.."
mkdir -p $BASEDIR/results
cd $BASEDIR/results
echo "" > area_volume_center_deltas.csv

# Iterate over combinations of cells and cuts
echo "" > all_cells_points.txt
for FE in $(ls $BASEDIR/data/*-30.fe); do
    cat ${FE} ${BASEDIR}/etc/AreaVolumeCenter_Delta.txt | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > /tmp/evolver.tmp
    DELTA=$(echo /tmp/evolver.tmp | evolver -x 2>/dev/null | grep 'Distance between area center and volume center' | grep -v 'printf' | cut -f2 -d: | sed 's/\s//g')
    echo -e "$(basename ${FE})\t${DELTA}" >> area_volume_center_deltas.csv
    for START in $(cat $BASEDIR/etc/points.txt | sed 's/\s//g'); do
         CUT=$(echo $START | sed -e 's/\s//g' -e 's/\,/\n/g' | sed '/\./ s/\.\{0,1\}0\{1,\}$//' | tr '\n' ',' | sed 's/\,$//g')
         echo $FE $CUT >> all_cells_points.txt
    done
done

# Split up file in batches of 5000, since that is the max number of queued jobs allowed on Biocluster
rm -f split_cells_points_*
split -l 5000 all_cells_points.txt split_cells_points_ --additional-suffix='.txt'

# Gather split files
FILES=$(ls split_cells_points_*.txt)
#FILES=$(ls split_cells_points_aa.txt)
count=0
total=$(cat split_cells_points_*.txt | wc -l)

# Submit jobs based on cell and point combinations
cd $BASEDIR/jobs
for FILE in ${FILES}; do
    IFS=$'\n'
    for line in $(cat $BASEDIR/results/${FILE}); do
        IFS=$' '
        #echo "Submitting job: $(basename $(echo ${line} | awk '{print $1}')) $(echo ${line} | awk '{print $2}')"
        #echo predict_div.sh ${line} | qsub -l walltime=48:00:00 -j oe
        count=$(($count+1))
        echo -e "Processing ${line} $count/$total\n"
        predict_div.sh ${line}
        IFS=$'\n'
    done
done

