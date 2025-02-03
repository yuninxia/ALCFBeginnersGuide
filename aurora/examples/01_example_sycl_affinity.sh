#!/bin/bash -l
#PBS -l select=1
#PBS -l place=scatter
#PBS -l walltime=0:10:00
#PBS -q debug
#PBS -A Catalyst
#PBS -l filesystems=home:flare
#PBS -o logs/
#PBS -e logs/

cd ${PBS_O_WORKDIR}

# MPI example w/ 4 MPI ranks per node spread evenly across cores
NNODES=`wc -l < $PBS_NODEFILE`
NRANKS_PER_NODE=12
NDEPTH=1
NTHREADS=1

NTOTRANKS=$(( NNODES * NRANKS_PER_NODE ))
echo "NUM_OF_NODES= ${NNODES} TOTAL_NUM_RANKS= ${NTOTRANKS} RANKS_PER_NODE= ${NRANKS_PER_NODE} THREADS_PER_RANK= ${NTHREADS}"

EXE=./01_example_sycl

MPI_ARG="-n ${NTOTRANKS} --ppn ${NRANKS_PER_NODE} --depth=${NDEPTH} --cpu-bind depth "

# select subdevices by default or use helper script to affinitize MPI ranks to tiles
#export LIBOMPTARGET_DEVICES=subdevice
AFFINITY=""
#AFFINITY="../../../../HelperScripts/Aurora/set_affinity_gpu_4ccs.sh"
#AFFINITY="../../../../HelperScripts/Aurora/set_affinity_gpu_2ccs.sh"
AFFINITY="../../../../HelperScripts/Aurora/set_affinity_gpu.sh"

COMMAND="mpiexec ${MPI_ARG} ${EXE}"
echo "COMMAND= ${COMMAND}"
${COMMAND}
