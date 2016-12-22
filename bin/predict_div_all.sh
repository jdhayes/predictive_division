#!/bin/bash -l

# Evaluate arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--resume)
        shift # next argument
        re='^[0-9]+$'
        if [[ $1 =~ $re ]]; then
            RESUME=$1
        else
            echo "The resume argument must be an integer."
            exit 1
        fi
        ;;
        *)
        # unknown argument
        echo "Usage: `basename $0`[-r]"
        exit 1
        ;;
    esac
    shift # next argument
done

# Load surface evolver into PATH
module load surface-evolver

# Set base directory in relation to the location of current script
BASEDIR="$(dirname $0)/.."

# Initialize results directory
if [[ ! -d $BASEDIR/results ]]; then
    mkdir -p $BASEDIR/results
fi

# Enter results directory
cd $BASEDIR/results

if [[ -z ${RESUME} ]]; then
    # Initialize files
    TMPFILE=$(mktemp)
    echo "" > area_volume_center_deltas.csv
    echo "" > all_cells_points.txt
    echo "v" > /tmp/evolver_v.tmp

    # Iterate over combinations of cells and starting points
    for FE in $(ls $BASEDIR/data/*-30.fe); do
        cat ${FE} /tmp/evolver_v.tmp | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > ${TMPFILE}
        VOL=$(echo ${TMPFILE} | evolver -x 2>/dev/null | egrep -A 1 '^Body' | awk '{print $3}' | grep -oP '[-\.0-9]+')
        echo -e "$(basename ${FE})\t${VOL}" >> cell_volumes.csv

        cat ${FE} ${BASEDIR}/etc/AreaVolumeCenter_Delta.txt | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > ${TMPFILE}
        DELTA=$(echo ${TMPFILE} | evolver -x 2>/dev/null | grep 'Distance between area center and volume center' | grep -v 'printf' | cut -f2 -d: | sed 's/\s//g')
        echo -e "$(basename ${FE})\t${DELTA}" >> area_volume_center_deltas.csv
        for START in $(cat $BASEDIR/etc/points.txt | sed 's/\s//g'); do
             POINT=$(echo $START | sed -e 's/\s//g' -e 's/\,/\n/g' | sed '/\./ s/\.\{0,1\}0\{1,\}$//' | tr '\n' ',' | sed 's/\,$//g')
             echo $FE $POINT >> all_cells_points.txt
        done
    done
    # Delete temp files
    rm -f ${TMPFILE} /tmp/evolver_v.tmp

    # Split up file in batches of 5000, since that is the max number of queued jobs allowed on Biocluster
    rm -f split_cells_points_*
    split -l 5000 all_cells_points.txt split_cells_points_ --additional-suffix='.txt'
fi

# Gather split files
if [[ $RESUME -gt 0 ]] && [[ $RESUME -lt 10 ]]; then
    # Only select a single cell-point file identified by the RESUME index
    FILES=$(ls split_cells_points_*.txt | head -n ${RESUME} | tail -1)
else
    # Select all cell and point combinations
    #FILES=$(ls split_cells_points_*.txt)
     
    # Select the first cell-point file
    FILES=$(ls split_cells_points_*.txt | head -1)
fi

# Track counts of cells
#count=0
#total=$(cat split_cells_points_*.txt | wc -l)

# Submit jobs based on cell and point combinations
cd $BASEDIR/jobs
for FILE in ${FILES}; do
    IFS=$'\n'
    for line in $(cat $BASEDIR/results/${FILE}); do
        IFS=$' '
        # Submit to job to cluster
        echo "Submitting job: $(basename $(echo ${line} | awk '{print $1}')) $(echo ${line} | awk '{print $2}')"
        echo predict_div.sh ${line} | qsub -l walltime=48:00:00 -j oe

        # Run Locally
        #count=$(($count+1))
        #echo -e "Processing ${line} $count/$total\n"
        #predict_div.sh ${line}
        IFS=$'\n'
    done
done

