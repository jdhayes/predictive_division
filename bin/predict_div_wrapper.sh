#!/bin/bash -l

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=1G
#SBATCH --time=0-72:00:00
#SBATCH -p batch
#SBATCH --job-name="PredDiv"

predict_div.sh $@

