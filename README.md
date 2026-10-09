# 大数据系统基本实验

Linux 常用命令、HDFS Shell/Java 操作及 MapReduce 入门程序。

## 环境

已在 Ubuntu 22.04.5 LTS、OpenJDK 11、Hadoop 3.4.3 的伪分布式 HDFS/YARN 环境中运行验证。

## 编译

```bash
export HADOOP_HOME=/usr/local/hadoop
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
bash build.sh
```

## HDFS Java 操作

```bash
hadoop jar lab1.jar HdfsTool upload local.txt /user/hadoop/demo.txt overwrite
hadoop jar lab1.jar HdfsTool download /user/hadoop/demo.txt downloaded.txt
hadoop jar lab1.jar HdfsTool cat /user/hadoop/demo.txt
hadoop jar lab1.jar HdfsTool stat /user/hadoop/demo.txt
hadoop jar lab1.jar HdfsTool list /user/hadoop
hadoop jar lab1.jar HdfsTool create-file /user/hadoop/nested/empty.txt
hadoop jar lab1.jar HdfsTool delete-file /user/hadoop/nested/empty.txt
hadoop jar lab1.jar HdfsTool mkdir /user/hadoop/newdir
hadoop jar lab1.jar HdfsTool rmdir /user/hadoop/newdir
hadoop jar lab1.jar HdfsTool append /user/hadoop/demo.txt tail 'suffix'
hadoop jar lab1.jar HdfsTool move /user/hadoop/demo.txt /user/hadoop/moved.txt
```

上传冲突时由参数选择 `append`、`overwrite` 或 `error`；下载遇到同名文件会自动加编号。目录删除仅允许空目录。内容前插把 `tail` 改为 `head`，通过新文件与重命名完成，并输出保留的原文件备份路径。

HDFS FileStatus 的时间字段为最后修改时间，不是通用创建时间。

## Shell 对照与 MapReduce

Hadoop 服务启动后，使用新的、尚不存在的 HDFS 实验目录：

```bash
export LAB_HDFS_ROOT=/user/hadoop/lab1-demo
bash run_hdfs.sh
bash run_mapreduce.sh
```

`run_hdfs.sh` 同时演示基础上传/下载和10项 Java/Shell 对照操作。基础部分还使用 `/user/hadoop/test` 和 `$HADOOP_HOME/test`，这些目标存在时会停止，避免覆盖已有文件。

单独运行三个作业：

```bash
hadoop jar lab1.jar LabMapReduce dedup INPUT OUTPUT
hadoop jar lab1.jar LabMapReduce sort INPUT OUTPUT
hadoop jar lab1.jar LabMapReduce family INPUT OUTPUT
```

`data/` 保存输入样例，`expected/` 保存验证过的输出。三个作业分别得到9条去重记录、11条带排名的排序记录、12条祖孙关系。

```bash
python3 verify_outputs.py results
```

验证程序从原始输入计算预期结果，并逐条比较实际输出。运行生成的文件位于 `results/`，编译文件位于 `build/`，均不进入仓库。

## Linux 命令练习

`run_linux.sh` 按实验要求演示目录、文件、文本、时间、所有者与 tar 操作。它需要 sudo 权限，使用题目指定的 `/tmp`、`/usr` 和根目录测试路径；任何目标预先存在都会停止。应在专用实验环境中运行。
