#!/bin/bash -l

EVOLVER="evolver"
BASEDIR="$(dirname $0)/.."


# Set current directory to whatever is passed in
if [[ ! -z "$1" ]]; then
    cd "$1"
fi

# Define important files
PPBFILE=$(ls *PPB2.fe 2>/dev/null | head -1)
CELLNAME=${PWD##*/}
if [[ -z $PPBFILE ]]; then
    echo -e "${CELLNAME}\tERROR\tNO PPBFILE"
    exit
fi

# Run through each fe file and merge PPB and predictive division
for DMPFILE in $(ls *.dmp); do
    # Get uniq name, by energy metric
    DMP=$(echo ${DMPFILE} | grep -oP '[0-9]+\.[0-9]+\.dmp$' | sed 's/\.dmp//g');
    
    # Merge all sources into a single fe file and replace VARs and remove broken code
    mkdir -p ${BASEDIR}/results/${CELLNAME}
    cat ${DMPFILE} ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/${PPBFILE}/g" | sed "s/showq//g" | sed "s/ee\.e_boundary/0/g" > ${BASEDIR}/results/${CELLNAME}/${DMP}_merged

    # Run evolver with fe and data files
    PRED=$(echo ${BASEDIR}/results/${CELLNAME}/${DMP}_merged | ${EVOLVER} 2>${BASEDIR}/results/${CELLNAME}/${DMP}_error.log | tail -2 | head -1 | grep -oP "[0-9\.]+")
    #echo "${BASEDIR}/results/${CELLNAME}/${DMP}_merged" | ${EVOLVER}
    
    # Print out Name and Prediction
    ERROR=$(cat ${BASEDIR}/results/${CELLNAME}/${DMP}_error.log | wc -l)
    if [[ ! "${ERROR}" -gt "0" ]]; then
        echo -e "${CELLNAME}\t${DMP}\t${PRED}"
        rm -f ${BASEDIR}/results/${CELLNAME}/${DMP}_error.log
    else
        echo -e "${CELLNAME}\t${DMP}\tERROR"
    fi

done

