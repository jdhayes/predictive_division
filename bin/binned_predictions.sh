#!/bin/bash

# Set base directory in relation to the location of current script
BASEDIR="$(dirname $0)/.."

# Set working dir
cd ${BASEDIR}/results

# Iterate over each cell directory
for dir in $(find . -maxdepth 1 -type d);
    # Bin results by energy, and count total of each bin
    do echo "=========$dir========";
    cat $dir/prediction.csv | awk '{print $3}' | sort -n | cut -d. -f1 | uniq -c; 
    echo '===========END============';
done  > binned_predictions.txt

