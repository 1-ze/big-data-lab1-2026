#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build results
: "${HADOOP_HOME:?Set HADOOP_HOME to the installed Hadoop directory}"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
javac -encoding UTF-8 -cp "$(hadoop classpath --glob)" -d build src/HdfsTool.java src/LabMapReduce.java
jar cf lab1.jar -C build .
printf 'BUILD_OK\n'
