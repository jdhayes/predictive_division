#!/bin/bash -l

module load surface-evolver

# First check for arguments
ARGS=2        # Number of arguments expected.
E_BADARGS=65  # Exit value if incorrect number of args passed.
test $# -ne $ARGS && echo -e "Usage:\n\t$(basename $0) <FE 30 filename> <Starting Point>\n\nExample:\n\t/path/to/data/30.fe 0.5,0.5,0.5" && exit $E_BADARGS

#EVOLVER="evolver -x -p2"
EVOLVER="evolver -x"
BASEDIR="$(dirname $0)/.."
SMOOTH=$(basename $1)
CELLNAME=${SMOOTH%-30.fe}
DIR="\.\.\/\.\.\/data"
START=$2 #"0.5,0.5,0.5"

# Print out what we are working on
echo "Working on job: $SMOOTH $START"

# Create CELL working directory
mkdir -p ${BASEDIR}/results/${CELLNAME} && cd ${BASEDIR}/results/${CELLNAME}

# Convert STL file to FE files and create spherical harmonics 30 FE file
if [[ ! -f ${BASEDIR}/data/${SMOOTH} ]]; then
    ${BASEDIR}/bin/spherical_harmonics.sh ${CELLNAME}.stl
    EXITCODE=$?
fi

# Define important files
PPBFILE="$(echo ${CELLNAME} | sed 's/_[oO]*u[t]*line$//g')_PPB2.fe"
if [[ -z $BASEDIR/data/$SMOOTH ]]; then
    echo -e "${CELLNAME}\tERROR\tNO Smooth file"
    exit 1
fi
if [[ -z $BASEDIR/data/$PPBFILE ]]; then
    echo -e "${CELLNAME}\tERROR\tNO PPBFILE"
    exit 1
fi

# Clean SphericalHarmonics (smooth) FE file
sed "s/ee\.e_boundary/0/g" $BASEDIR/data/${SMOOTH} | sed "s/^showq;//g" > smooth_${START//,/-}.fe
echo -e "\n// Add starting point for cut\nrun ($START)" >> smooth_${START//,/-}.fe
CUT=$(echo smooth_${START//,/-}.fe | ${EVOLVER} 1>/dev/null 2>smooth_${START//,/-}_error.log; wait)
#${PIPESTATUS[1]}

# Determine dump file
DMPFILE=$(ls ${CELLNAME}-${START//,/-}-*.dmp)

# Process merge DMP, PPB and process predictive division
if [[ -f "$DMPFILE" ]]; then
    # Not sure why this is here, maybe it could be a good place to check the CUT
    #"$CUT" -eq 0
    
    # Get uniq name, by energy metric
    DMP=$(echo ${DMPFILE} | grep -oP '[0-9]+\.[0-9]+\.dmp$' | sed 's/\.dmp//g');

    # Merge all sources into a single fe file and replace VARs and remove broken code
    cat ${DMPFILE} ${BASEDIR}/etc/PPB_OFFSET.txt | sed "s/PPBFILE/$DIR\/$PPBFILE/g" | sed "s/showq//g" | sed "s/ee\.e_boundary/0/g" > ${DMP}_merged

    # Create "ghost" prediction for visualization purposes
    cat ${BASEDIR}/data/${SMOOTH} ${BASEDIR}/etc/COLOR_MASK.txt ${BASEDIR}/etc/PB_OFFSET.txt | sed "s/PPBFILE/$DIR\/${PPBFILE}/g" | sed "s/DMPFILE/${DMPFILE}/g" | sed "s/showq//g" | sed "s/ee\.e_boundary/0/g" > ${DMP}_merged_ghost;
    echo "showq" >> ${DMP}_merged_ghost

    # Run evolver with fe and data files
    RESULT=($(echo ${DMP}_merged | ${EVOLVER} 2>${DMP}_error.log | tail -4 | egrep "^\s" | grep -oP "[0-9\.]+"; echo ${PIPESTATUS[1]}))
    PRED=${RESULT[0]}
    ERROR=${RESULT[1]}

    # Check if we have errors
    ISEMPTY=$(cat ${DMP}_error.log | wc -l)
    if [[ "$ISEMPTY" == 0 ]]; then
        rm -f ${DMP}_error.log
    fi

    # Print out Name and Prediction
    touch prediction.csv
    if [[ ! -z "${ERROR}" && "${ERROR}" -eq 0 ]]; then
        echo -e "${CELLNAME}\t${START}\t${DMP}\t${PRED}" >> prediction.csv
    else
        echo -e "${CELLNAME}\t${START}\t${DMP}\tERROR: Prediction failed" >> prediction.csv
    fi
else
    echo -e "${CELLNAME}\t${START}\tNA\tERROR: No dump file" >> prediction.csv
    exit
fi

