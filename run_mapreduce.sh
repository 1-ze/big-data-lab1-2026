#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${HADOOP_HOME:?}"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
: "${LAB_HDFS_ROOT:?Use a fresh dedicated HDFS lab directory}"
mkdir -p results
exec > >(tee results/mapreduce.log) 2>&1
set -x
hdfs dfs -mkdir -p "$LAB_HDFS_ROOT/input/dedup" "$LAB_HDFS_ROOT/input/sort" "$LAB_HDFS_ROOT/input/family"
hdfs dfs -put data/A.txt data/B.txt "$LAB_HDFS_ROOT/input/dedup/"
hdfs dfs -put data/numbers1.txt data/numbers2.txt data/numbers3.txt "$LAB_HDFS_ROOT/input/sort/"
hdfs dfs -put data/family.txt "$LAB_HDFS_ROOT/input/family/"
for job in dedup sort family; do
    hadoop jar lab1.jar LabMapReduce "$job" "$LAB_HDFS_ROOT/input/$job" "$LAB_HDFS_ROOT/output/$job"
    hdfs dfs -test -e "$LAB_HDFS_ROOT/output/$job/_SUCCESS"
    hdfs dfs -cat "$LAB_HDFS_ROOT/output/$job/part-r-00000" > "results/$job.txt"
    cat "results/$job.txt"
done
python3 verify_outputs.py results | tee results/verification.json
printf 'MAPREDUCE_ALL_PASS\n'
