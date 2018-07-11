#!/bin/bash -l

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1G
#SBATCH --time=3-12:00:00
#SBATCH --job-name="PredDiv"
#SBATCH -p batch # Batch partition supports true single core jobs

predict_div.sh $@

