#!/bin/bash -l

# First check for arguments
ARGS=2        # Number of arguments expected.
E_BADARGS=65  # Exit value if incorrect number of args passed.
test $# -ne $ARGS && echo -e "Usage:\n\t$(basename $0) <FE 30 filename> <Starting Point>\n\nExample:\n\t/path/to/data/30.fe 0.5,0.5,0.5" && exit $E_BADARGS

EVOLVER="evolver"
BASEDIR="$(dirname $0)/.."
SMOOTH=$(basename $1)
DIR="\.\.\/\.\.\/data"
START=$2 #"0.5,0.5,0.5"

# Define important files
CELLNAME=${SMOOTH%-30.fe}
PPBFILE="${CELLNAME}_PPB.fe"
if [[ -z $BASEDIR/data/$SMOOTH ]]; then
    echo -e "${CELLNAME}\tERROR\tNO Smooth file"
    exit
fi
if [[ -z $BASEDIR/data/$PPBFILE ]]; then
    echo -e "${CELLNAME}\tERROR\tNO PPBFILE"
    exit
fi

# Clean SphericalHarmonics (smooth) FE file
mkdir -p ${BASEDIR}/results/${CELLNAME} && cd ${BASEDIR}/results/${CELLNAME}
sed "s/ee\.e_boundary/0/g" $BASEDIR/data/${SMOOTH} | sed "s/^showq;//g" > smooth_${START//,/-}.fe
echo -e "\n// Add starting point for cut\nrun ($START)" >> smooth_${START//,/-}.fe
CUT=$(echo smooth_${START//,/-}.fe | ${EVOLVER} 2>smooth_${START//,/-}_error.log)

# Run through each fe file and merge PPB and predictive division
for DMPFILE in $(ls *.dmp); do
    # Get uniq name, by energy metric
    DMP=$(echo ${DMPFILE} | grep -oP '[0-9]+\.[0-9]+\.dmp$' | sed 's/\.dmp//g');
    
    # Merge all sources into a single fe file and replace VARs and remove broken code
    cat ${DMPFILE} ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/$DIR\/$PPBFILE/g" | sed "s/showq//g" | sed "s/ee\.e_boundary/0/g" > ${DMP}_merged

    # Run evolver with fe and data files
    PRED=$(echo ${DMP}_merged | ${EVOLVER} 2>${DMP}_error.log | tail -2 | head -1 | grep -oP "[0-9\.]+")
    #echo "${DMP}_merged" | ${EVOLVER}
    
    # Print out Name and Prediction
    ERROR=$(cat ${DMP}_error.log | wc -l)
    touch prediction.csv
    if [[ ! "${ERROR}" -gt "0" ]]; then
        echo -e "${CELLNAME}\t${DMP}\t${PRED}" >> prediction.csv
        rm -f ${DMP}_error.log
    else
        echo -e "${CELLNAME}\t${DMP}\tERROR" >> prediction.csv
    fi

done

