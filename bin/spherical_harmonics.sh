#!/bin/bash -l 

#set -xe

module load surface-evolver

BASEDIR="$(dirname $0)/.."
EVOLVER="evolver -x"
STL=$(basename $1)
CELLNAME=${STL%.stl}
SMOOTH=${CELLNAME}-30.fe

echo "Enter Direcotry"
mkdir -p ${BASEDIR}/results/${CELLNAME}/SH
cd ${BASEDIR}/results/${CELLNAME}/SH

echo "Convert STL to FE:"
if [[ ! -f ${CELLNAME}.fe ]]; then
    ${BASEDIR}/bin/stl2fe ${BASEDIR}/data/stls/${CELLNAME}.stl > ${CELLNAME}.fe || true
fi
if [[ ! -f ${CELLNAME}_PPB2.fe ]]; then
    ${BASEDIR}/bin/stl2fe ${BASEDIR}/data/stls/${CELLNAME}_PPB2.stl > ${CELLNAME}_PPB2.fe || true
fi
# For some reason the exit code from stl2fe is 52, so set it to zero
#EXITCODE=$?
EXITCODE=0

if [[ ${EXITCODE} -eq 0 ]]; then
    if [[ ! -L SphericalHarmonics.cmd ]]; then ln -s ${BASEDIR}/etc/SphericalHarmonics.cmd . ; fi
    if [[ ! -L slicer.cmd ]]; then ln -s ${BASEDIR}/etc/slicer.cmd . ; fi
    if [[ ! -L stl.cmd ]]; then ln -s ${BASEDIR}/etc/stl.cmd . ; fi
    if [[ ! -L header.inc ]]; then ln -s ${BASEDIR}/etc/header.inc . ; fi
    if [[ ! -L trailer.inc ]]; then ln -s ${BASEDIR}/etc/trailer.inc . ; fi
    if [[ ! -f harmonic.inc ]]; then cp ${BASEDIR}/etc/harmonic.inc . ; fi
    if [[ ! -L inertia.txt ]]; then ln -s ${BASEDIR}/etc/inertia.txt . ; fi
    if [[ ! -L inertia_defs.txt ]]; then ln -s ${BASEDIR}/etc/inertia_defs.txt . ; fi
    if [[ ! -L cm_defs.txt ]]; then ln -s ${BASEDIR}/etc/cm_defs.txt . ; fi
    EXITCODE=$?
fi

if [[ ${EXITCODE} -eq 0 ]]; then
    echo "Prepend header"
    cat header.inc ${CELLNAME}.fe > ${CELLNAME}_header.fe
    EXITCODE=$?
else
    echo -e "CONVERSION VAILED $EXITCODE"
    EXITCODE=1
fi


if [[ ${EXITCODE} -eq 0 && ! -f 30.inc ]]; then
    echo "Calculate Harmonics"
    ${EVOLVER} -r "AltCalcHarmonics(30) >>> \"30.inc\"; quit 0" -f trailer.inc ${CELLNAME}_header.fe &> /dev/null && sed -i 's/Quiet OFF/\/\/Quiet OFF/g' 30.inc
    EXITCODE=$?
fi

if [[ -f 30.inc && ${EXITCODE} -eq 0 ]]; then
    echo "Copy harmonic file"
    cp 30.inc harmonic.inc
    EXITCODE=$?
fi

if [[ ${EXITCODE} -eq 0 ]]; then
    echo "Grooming"
    ${EVOLVER} -r "harmonic_order:=30;basename:=\"${CELLNAME}\";groom_shell; quit 0" -f trailer.inc ${CELLNAME}_header.fe &> /dev/null
    EXITCODE=$?
fi

if [[ ${EXITCODE} -eq 0 ]]; then
    echo "Copy final FE files to data directory"
    cp ${CELLNAME}_PPB2.fe ${BASEDIR}/data/
    cp ${SMOOTH} ${BASEDIR}/data/
    EXITCODE=$?
fi

# Calculate moment of inertia matrix, eigenvalues and eigenvectors
if [[ ${EXITCODE} -eq 0 && ! -f ../eigenvalue_ratio.csv ]]; then
    echo "Calculate moment of inertia matrix, eigenvalues and eigenvectors"
    > ../eigenvalue_ratio.csv
    TMPFILE=$(mktemp)
    cat ${BASEDIR}/data/${SMOOTH} | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > ${TMPFILE}
    EIGENVAL=$(${EVOLVER} -r "calc_inertia; quit 0;" -f "inertia.txt" ${TMPFILE} | tee eigenvalue_ratio.log | tail -n 1 | cut -d: -f2 | sed 's/ //g')
    
    # Save eigenvalue ratio
    echo -e "${SMOOTH}\t${EIGENVAL}" >> ../eigenvalue_ratio.csv
    rm -f ${TMPFILE}
fi

# Calculate cell volume and volume center delta
if [[ ${EXITCODE} -eq 0 && -f ${BASEDIR}/data/${SMOOTH} && -f ${BASEDIR}/data/${CELLNAME}_PPB2.fe && ! -f ../cell_volume.csv && ! -f ../cell_volume.csv ]]; then
    # Initialize files
    > ../cell_volume.csv
    > ../area_volume_center_delta.csv
    echo "v" > /tmp/evolver_v.tmp
    TMPFILE=$(mktemp)

    echo -e "Calculating cell volume and area volume center delta\n"

    cat ${BASEDIR}/data/${SMOOTH} /tmp/evolver_v.tmp | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > ${TMPFILE}
    VOL=$(echo ${TMPFILE} | ${EVOLVER} 2>/dev/null | egrep -A 1 '^Body' | awk '{print $3}' | grep -oP '[-\.0-9]+')
    echo -e "${SMOOTH}\t${VOL}" >> ../cell_volume.csv

    cat ${BASEDIR}/data/${SMOOTH} ${BASEDIR}/etc/AreaVolumeCenter_Delta.cmd | sed 's/ee\.e_boundary/0/g' | sed 's/showq//g' > ${TMPFILE}
    DELTA=$(echo ${TMPFILE} | ${EVOLVER} 2>/dev/null | grep 'Distance between area center and volume center' | grep -v 'printf' | cut -f2 -d: | sed 's/\s//g')
    echo -e "${SMOOTH}\t${DELTA}" >> ../area_volume_center_delta.csv

    # Delete temp files
    rm -f ${TMPFILE} /tmp/evolver_v.tmp
fi

exit ${EXITCODE}

