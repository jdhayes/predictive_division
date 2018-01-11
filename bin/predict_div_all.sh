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

# Set base directory in relation to the location of current script
BASEDIR="$(dirname $0)/.."

# Initialize results directory
if [[ ! -d $BASEDIR/results ]]; then
    mkdir -p $BASEDIR/results
fi

# Enter results directory
cd $BASEDIR/results

if [[ -z ${RESUME} ]]; then
    # Initialize file
    echo "" > all_cells_points.txt

    # Iterate over combinations of cells and starting points
    NUM_CELLS=0
    for STL in $(ls $BASEDIR/data/stls/*.stl | egrep -v "_PPB2.stl"); do
        for START in $(cat $BASEDIR/etc/points.txt | sed 's/\s//g'); do
             POINT=$(echo $START | sed -e 's/\s//g' -e 's/\,/\n/g' | sed '/\./ s/\.\{0,1\}0\{1,\}$//' | tr '\n' ',' | sed 's/\,$//g')
             echo ${STL%.stl}-30.fe $POINT >> all_cells_points.txt
        done
        NUM_CELLS=$((${NUM_CELLS} + 1))
    done

    # Split up file in batches of N, where N is 2500 minus number of cells, since the max number of queued jobs allowed on UCR's HPCC cluster is 5000
    rm -f split_cells_points_*
    split -l $((2500 - ${NUM_CELLS})) all_cells_points.txt split_cells_points_ --additional-suffix='.txt'
fi

# Gather split files
if [[ $RESUME -gt 0 ]] && [[ $RESUME -lt 10 ]]; then
    # Only select a single cell-point file identified by the RESUME index
    FILES=$(ls split_cells_points_*.txt | head -n ${RESUME} | tail -1)
else
    # Select all cell and point combinations
    #FILES=$(ls split_cells_points_*.txt)
     
    # Select the first 2 cell-point files, so that we max out the 5000 job limit
    FILES=$(ls split_cells_points_*.txt | head -2)
fi

# Submit jobs based on cell and point combinations
cd $BASEDIR/jobs
PREV_CELL="None"
for FILE in ${FILES}; do
    IFS=$'\n'
    for line in $(cat $BASEDIR/results/${FILE}); do
        IFS=$' '
        SMOOTH=$(echo ${line} | awk '{print $1}')
        CELLNAME=${SMOOTH%-30.fe}

        # Submit job to Cluster, or run locally
        echo "Submitting job: $(basename $(echo ${line} | awk '{print $1}')) $(echo ${line} | awk '{print $2}')"
       
        # Make sure that submissions to cluster schedulers are using dependancy control
        if [[ ${PREV_CELL} == "None" || ! $PREV_CELL == $CELLNAME ]]; then
            # Torque
            #SH_JOBID=$(echo spherical_harmonics.sh ${CELLNAME}.stl | qsub -l walltime=2:00:00 -j oe)

            # Slurm
            SH_JOBID=$(sbatch -p short,batch --time=2:00:00 --wrap="spherical_harmonics.sh ${CELLNAME}.stl" | grep -Po '[0-9]*$')
        fi

        # Torque
        #echo predict_div.sh ${line} | qsub -l walltime=72:00:00 -j oe -W depend=afterok:${SH_JOBID}
        
        # Slurm
        if [[ ! -z ${SH_JOBID} ]]; then
            sbatch --dependency=afterok:${SH_JOBID} predict_div_wrapper.sh ${line}
        else
            echo "ERROR: SH_JOBID is empty, exiting."
            exit 1
        fi

        # Run Locally, this is done in serial to make sure that local resources are not overwhelmed
        #predict_div.sh ${line}

        PREV_CELL=${CELLNAME}
        IFS=$'\n'
    done
done

