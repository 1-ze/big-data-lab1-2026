#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${HADOOP_HOME:?}"
: "${LAB_HDFS_ROOT:?}"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
mkdir -p results/downloads
exec > >(tee results/hdfs.log) 2>&1
JAR=$(pwd)/lab1.jar
tool() { hadoop jar "$JAR" HdfsTool "$@"; }
assert_content() {
    local path=$1 expected=$2
    local actual
    actual=$(hdfs dfs -cat "$path")
    [[ "$actual" == "$expected" ]] || { printf 'CONTENT_CHECK_FAILED %s\n' "$path"; return 1; }
    printf 'CONTENT_PASS %s\n' "$path"
}
if hdfs dfs -test -e "$LAB_HDFS_ROOT"; then printf 'PREEXISTING_HDFS_ROOT_STOP\n'; exit 2; fi
set -x
default_fs=$(hdfs getconf -confKey fs.defaultFS)
[[ "$default_fs" == hdfs://* ]] || { printf 'NOT_AN_HDFS_CONFIGURATION %s\n' "$default_fs"; exit 2; }
hdfs dfs -mkdir -p /user/hadoop
if hdfs dfs -test -e /user/hadoop/test; then
    printf 'PREEXISTING_BASIC_TEST_STOP\n'; exit 2
fi
hdfs dfs -mkdir /user/hadoop/test
hdfs dfs -put "$HOME/.bashrc" /user/hadoop/test/
hdfs dfs -ls /user/hadoop/test
if [[ -e "$HADOOP_HOME/test" ]]; then printf 'PREEXISTING_LOCAL_TEST_STOP\n'; exit 2; fi
hdfs dfs -get /user/hadoop/test "$HADOOP_HOME/"
cmp "$HOME/.bashrc" "$HADOOP_HOME/test/.bashrc"
printf 'BASIC_HDFS_COPY_PASS\n'
printf 'alpha\n' > results/upload.txt
printf 'beta\n' > results/add.txt

# 1 Upload: Java and Shell, each covering append and overwrite.
tool upload results/upload.txt "$LAB_HDFS_ROOT/java/document.txt" error
tool upload results/add.txt "$LAB_HDFS_ROOT/java/document.txt" append
assert_content "$LAB_HDFS_ROOT/java/document.txt" $'alpha\nbeta'
tool upload results/upload.txt "$LAB_HDFS_ROOT/java/document.txt" overwrite
assert_content "$LAB_HDFS_ROOT/java/document.txt" alpha
hdfs dfs -mkdir -p "$LAB_HDFS_ROOT/shell"
hdfs dfs -put results/upload.txt "$LAB_HDFS_ROOT/shell/document.txt"
hdfs dfs -appendToFile results/add.txt "$LAB_HDFS_ROOT/shell/document.txt"
assert_content "$LAB_HDFS_ROOT/shell/document.txt" $'alpha\nbeta'
hdfs dfs -put -f results/upload.txt "$LAB_HDFS_ROOT/shell/document.txt"
assert_content "$LAB_HDFS_ROOT/shell/document.txt" alpha

# 2 Download collisions preserve the original local file.
printf 'local-original\n' > results/downloads/java.txt
tool download "$LAB_HDFS_ROOT/java/document.txt" results/downloads/java.txt
cmp results/upload.txt results/downloads/java_1.txt
[[ $(cat results/downloads/java.txt) == local-original ]]
printf 'local-original\n' > results/downloads/shell.txt
dest=results/downloads/shell.txt
n=0
while [[ -e "$dest" ]]; do n=$((n+1)); dest="results/downloads/shell_$n.txt"; done
hdfs dfs -get "$LAB_HDFS_ROOT/shell/document.txt" "$dest"
cmp results/upload.txt "$dest"

# 3 Cat. 4 Stat. 5 Recursive file listing.
tool cat "$LAB_HDFS_ROOT/java/document.txt"
hdfs dfs -cat "$LAB_HDFS_ROOT/shell/document.txt"
tool stat "$LAB_HDFS_ROOT/java/document.txt"
hdfs dfs -ls "$LAB_HDFS_ROOT/shell/document.txt"
hdfs dfs -stat 'size=%b mtime=%y name=%n' "$LAB_HDFS_ROOT/shell/document.txt"
tool list "$LAB_HDFS_ROOT/java"
hdfs dfs -ls -R "$LAB_HDFS_ROOT/shell"

# 6 Create/delete files with automatic parents.
tool create-file "$LAB_HDFS_ROOT/java/nested/new.txt"
tool delete-file "$LAB_HDFS_ROOT/java/nested/new.txt"
! hdfs dfs -test -e "$LAB_HDFS_ROOT/java/nested/new.txt"
hdfs dfs -mkdir -p "$LAB_HDFS_ROOT/shell/nested"
hdfs dfs -touchz "$LAB_HDFS_ROOT/shell/nested/new.txt"
hdfs dfs -rm "$LAB_HDFS_ROOT/shell/nested/new.txt"
! hdfs dfs -test -e "$LAB_HDFS_ROOT/shell/nested/new.txt"

# 7 Directories: refuse deletion of a populated directory, delete an empty one.
tool mkdir "$LAB_HDFS_ROOT/java/empty/deep"
tool rmdir "$LAB_HDFS_ROOT/java/empty"
hdfs dfs -test -d "$LAB_HDFS_ROOT/java/empty/deep"
tool rmdir "$LAB_HDFS_ROOT/java/empty/deep"
hdfs dfs -mkdir -p "$LAB_HDFS_ROOT/shell/empty/deep"
if hdfs dfs -rmdir "$LAB_HDFS_ROOT/shell/empty"; then exit 3; else printf 'SHELL_REFUSED_NONEMPTY_PASS\n'; fi
hdfs dfs -rmdir "$LAB_HDFS_ROOT/shell/empty/deep"

# 8 Append at tail and prepend at head, preserving the shell backup.
tool append "$LAB_HDFS_ROOT/java/document.txt" tail $'TAIL\n'
tool append "$LAB_HDFS_ROOT/java/document.txt" head $'HEAD\n'
assert_content "$LAB_HDFS_ROOT/java/document.txt" $'HEAD\nalpha\nTAIL'
printf 'TAIL\n' | hdfs dfs -appendToFile - "$LAB_HDFS_ROOT/shell/document.txt"
{ printf 'HEAD\n'; hdfs dfs -cat "$LAB_HDFS_ROOT/shell/document.txt"; } > results/prepend.txt
hdfs dfs -put results/prepend.txt "$LAB_HDFS_ROOT/shell/replacement.txt"
hdfs dfs -mv "$LAB_HDFS_ROOT/shell/document.txt" "$LAB_HDFS_ROOT/shell/prepend-backup.txt"
hdfs dfs -mv "$LAB_HDFS_ROOT/shell/replacement.txt" "$LAB_HDFS_ROOT/shell/document.txt"
assert_content "$LAB_HDFS_ROOT/shell/document.txt" $'HEAD\nalpha\nTAIL'

# 9 Delete files dedicated to this deletion test; retain document/output evidence.
tool create-file "$LAB_HDFS_ROOT/java/delete-me.txt"
tool delete-file "$LAB_HDFS_ROOT/java/delete-me.txt"
hdfs dfs -touchz "$LAB_HDFS_ROOT/shell/delete-me.txt"
hdfs dfs -rm "$LAB_HDFS_ROOT/shell/delete-me.txt"

# 10 Move without overwriting a pre-existing target.
tool move "$LAB_HDFS_ROOT/java/document.txt" "$LAB_HDFS_ROOT/java/moved.txt"
hdfs dfs -mv "$LAB_HDFS_ROOT/shell/document.txt" "$LAB_HDFS_ROOT/shell/moved.txt"
assert_content "$LAB_HDFS_ROOT/java/moved.txt" $'HEAD\nalpha\nTAIL'
assert_content "$LAB_HDFS_ROOT/shell/moved.txt" $'HEAD\nalpha\nTAIL'
! hdfs dfs -test -e "$LAB_HDFS_ROOT/java/document.txt"
! hdfs dfs -test -e "$LAB_HDFS_ROOT/shell/document.txt"
printf 'HDFS_ALL_PASS\n'
