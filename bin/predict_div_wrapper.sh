#!/bin/bash -l

#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --mem-per-cpu=1G
#SBATCH --time=3-12:00:00
#SBATCH --job-name="PredDiv"
#SBATCH -p intel,batch

predict_div.sh $@

