#!/bin/bash

# Set base directory in relation to the location of current script
BASEDIR="$(dirname $0)/.."

# Set working dir
cd ${BASEDIR}/results

# Compile all predictions
cat */prediction.csv > predictions.csv
cat */cell_volume.csv > cell_volumes.csv
cat */area_volume_center_delta.csv > area_volume_center_deltas.csv

# Fix perms, I should really do this within the job
#chgrp -R rasmussenlab .
find . -type f -exec chmod a+r {} \;
find . -type d -exec chmod a+rx {} \;

