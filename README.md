# Predictive Division
Cell Predictive Division

Hopefully the end of this project will result in a reusable pipeline that can smooth, cut and predict cell divisions.

# Install
TODO

# Usage
In order to run the pipeling you must first ensure that the data directory contains "\*-30.fe" files and "\*_PPB2.fe" files.
Each 30.fe file must have an identically named PPB2.fe file.

After the data has been properly formatted, then just run the following:
```
predict_div_all.sh
```
The above command will compute the area volume center deltas and the volumes for each cell and place these values within the corresponding files under the results directory:
    area_volume_center_deltas.csv
    cell_volumes.csv
    
Currently we use UCR's HPC Torque cluster and thus needs to be limited to maximum of 5000 jobs. Thus it will proceed to generate all combinations of cells and starting points and place these values under the results directory in a file called all_cells_points.txt, and then it will split up this file into smaller files of 5000 lines each.

Finally it will iterate over the first file and submit 5000 jobs to the cluster via qsub.
When all these jobs are completed, we can submit the next batch by using the resume argument, like so:
```
predict_div_all.sh --resume 2
```
The numerical value of 'resume' represents the Nth smaller batch file of 5000 jobs (1 job per line).
