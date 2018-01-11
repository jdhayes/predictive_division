# Predictive Division
Cell Predictive Division

This project is a reusable pipeline that can smooth, cut and predict cell divisions.

# Dependencies
This pipline utilizes Bash and Slurm to manage jobs. It is possible to run the pipeline in serial, thus removing the need for Slurm.
There are several assumptions made regarding how Slurm is used and what partitions are available.
These assumptions are compatibale with the UCR HPCC Cluster. For other Slurm implementations you will need to modify `predict_div_wrapper.sh`.

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
In order to run the pipeline you must first ensure that the data/stls directory contains "CELLNAME.stl" files and "CELLNAME_PPB2.stl" files.
Each "CELLNAME.stl" file must have a corresponding "CELLNAME_PPB2.stl" file with identical CELLNAMEs.

After the data has been properly formatted and placed within the ```data/stls``` directory, then just run the following:
```
predict_div_all.sh
```

Currently we use the UCR HPCC Cluster and it has a maximum of 5000 job submissions. The initial starting script will proceed to generate all combinations of cells and starting points and place these values under the results directory in a file called all_cells_points.txt, and then it will split up this file into smaller "batch" files of 2500 lines each. Each line is 1 job, so the batch files will be used to submit 2500 jobs at a time.

It will then iterate over the first two batch file and submit 5000 jobs (2 batch files, 2 x 2500 = 5000) to the cluster via sbatch.
Keep in mind that there is a dependency chain when submitting jobs to Slurm.
For every cell there is a primary job to convert the STL files to FE files and run spherical harmonics.
Also within the primary job the volume and area calculations are done.
Once the primary job for a given cell has completed, then all dependency jobs can then proceed to calculate predictions.

When at least half of these jobs have completed, we can submit the next batch by using the resume argument.
The following example will run the 3rd batch file of jobs, since the first 2 have already been submitted with the initial run of the pipeline:
```
predict_div_all.sh --resume 3
```

