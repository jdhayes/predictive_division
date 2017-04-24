#!/bin/bash

# Set working dir
cd ~/bigdata/predictive_division/results

# Compile all predictions
cat */prediction.csv > predictions.csv

# Fix perms, I should really do this within the job
chgrp -R rasmussenlab .
find . -type f -exec chmod a+r {} \;
find . -type d -exec chmod a+rx {} \;

