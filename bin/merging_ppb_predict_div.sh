#!/bin/bash -l

EVOLVER="evolver"
BASEDIR="$(dirname $0)/.."

# Set current directory to whatever is passed in
if [[ ! -z "$1" ]]; then
    echo "$1" 
    cd "$1"
fi

# Define important files
PPBFILE=$(ls *PPB2.fe); 
DMPLOWEST=$(ls *.dmp | grep -oP '[0-9]+\.[0-9]+\.dmp$' | sed 's/\.dmp//g' | sort -n | head -1);
DMPFILE=$(ls *${DMPLOWEST}.dmp)

# Run through each fe file and merge PPB and predictive division
for fe in $(ls *-30.fe); do
    # Merge all sources into a single fe file
    #echo "addload \"${DMPFILE}\";" > ${fe}_merged.fe
    #cat $fe ${BASEDIR}/etc/maybealittleok.txt ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/${PPBFILE}/g" | sed "s/DMPFILE/${DMPFILE}/g" | sed "s/showq//g" > ${BASEDIR}/results/${fe}_merged.fe;
    cat ${DMPFILE} ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/${PPBFILE}/g" | sed "s/showq//g" | sed "s/ee\.e_boundary/0/g" > ${BASEDIR}/results/${fe}_merged.fe;
    #cat $fe ${BASEDIR}/etc/ghost.txtt ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/${PPBFILE}/g" > ${BASEDIR}/results/${fe}_merged.fe;
    #cat ${BASEDIR}/etc/PPBaccuracyGREEN_Realz.txt | sed "s/PPBFILE/${PPBFILE}/g" > ${BASEDIR}/results/${fe}_merged.fe;

    # Run evolver with fe and data files
    echo ${BASEDIR}/results/${fe}_merged.fe | evolver | tail -2 | head -1 | grep -oP "[0-9\.]+"
    #echo ${EVOLVER} -f${BASEDIR}/results/${fe}_merged.fe ${DMPFILE} 
    #${EVOLVER} -f${DMPFILE} ${BASEDIR}/results/${fe}_merged.fe
    #${EVOLVER} -f${BASEDIR}/results/${fe}_merged.fe ${DMPFILE}
done

