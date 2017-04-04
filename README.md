# Predictive Division
Cell Predictive Division

Hopefully the end of this project will result in a reusable pipeline that can smooth, cut and predict cell divisions.

# Dependencies
This pipline utilizes Bash and Slurm to manage jobs.
There are several assumptions made regarding how Slurm is configured and what partitions are available.
Thes assumptions should be compatibale with the UCR HPCC Cluster.

# Install
Clone a copy of the code to a directory of your choice, you will need a GitHub account in order to do this:
```
git clone git@github.com:jdhayes/predictive_division.git
```
Then add the following lines to your .bashrc file:
```
export PATH=/wherever/you/cloned/predictive/division/bin:$PATH
```
Then source your changes:
```
source .bashrc
```

# Usage
In order to run the pipeline you must first ensure that the data directory contains "\*-30.fe" files and "\*_PPB2.fe" files.
Each 30.fe file must have an identically named PPB2.fe file.

After the data has been properly formatted and placed within the ```data``` directory, then just run the following:
```
predict_div_all.sh
```
The above command will compute the area volume center deltas and the volumes for each cell and place these values within the corresponding files under the results directory:
    area_volume_center_deltas.csv
    cell_volumes.csv
    
Currently we use the UCR HPCC Cluster and the pipeline submits jobs in batches of 5000. The initial starting script will proceed to generate all combinations of cells and starting points and place these values under the results directory in a file called all_cells_points.txt, and then it will split up this file into smaller "batch" files of 5000 lines each. Each line is 1 job, so the batch files will be used to submit 5000 jobs at a time.

Finally it will iterate over the first batch file and submit 5000 jobs to the cluster via sbatch.
When all these jobs are completed, we can submit the next batch by using the resume argument, like so:
```
predict_div_all.sh --resume 2
```
The numerical value of 'resume' represents the Nth batch file (set of 5000 jobs) created by the initial starting script.
