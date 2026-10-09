import java.io.IOException;
import java.util.*;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.*;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class LabMapReduce {
    public static class DedupMapper extends Mapper<LongWritable, Text, Text, NullWritable> {
        public void map(LongWritable key, Text value, Context c) throws IOException, InterruptedException {
            String line = value.toString().trim().replaceAll("\\s+", " ");
            if (!line.isEmpty()) c.write(new Text(line), NullWritable.get());
        }
    }
    public static class DedupReducer extends Reducer<Text, NullWritable, Text, NullWritable> {
        public void reduce(Text key, Iterable<NullWritable> values, Context c) throws IOException, InterruptedException {
            c.write(key, NullWritable.get());
        }
    }
    public static class SortMapper extends Mapper<LongWritable, Text, IntWritable, NullWritable> {
        public void map(LongWritable key, Text value, Context c) throws IOException, InterruptedException {
            String s = value.toString().trim();
            if (!s.isEmpty()) c.write(new IntWritable(Integer.parseInt(s)), NullWritable.get());
        }
    }
    public static class SortReducer extends Reducer<IntWritable, NullWritable, LongWritable, IntWritable> {
        private long rank = 0;
        public void reduce(IntWritable key, Iterable<NullWritable> values, Context c) throws IOException, InterruptedException {
            for (NullWritable ignored : values) c.write(new LongWritable(++rank), key);
        }
    }
    public static class FamilyMapper extends Mapper<LongWritable, Text, Text, Text> {
        public void map(LongWritable key, Text value, Context c) throws IOException, InterruptedException {
            String[] t = value.toString().trim().split("\\s+");
            if (t.length != 2 || (t[0].equalsIgnoreCase("child") && t[1].equalsIgnoreCase("parent"))) return;
            c.write(new Text(t[1]), new Text("C\t" + t[0]));
            c.write(new Text(t[0]), new Text("P\t" + t[1]));
        }
    }
    public static class FamilyReducer extends Reducer<Text, Text, Text, Text> {
        public void reduce(Text key, Iterable<Text> values, Context c) throws IOException, InterruptedException {
            Set<String> children = new TreeSet<>(), parents = new TreeSet<>();
            for (Text value : values) {
                String[] t = value.toString().split("\t", 2);
                (t[0].equals("C") ? children : parents).add(t[1]);
            }
            for (String child : children) for (String parent : parents) c.write(new Text(child), new Text(parent));
        }
    }
    public static void main(String[] a) throws Exception {
        if (a.length != 3) throw new IllegalArgumentException("dedup|sort|family INPUT OUTPUT");
        Job j = Job.getInstance(new Configuration(), "lab1-" + a[0]);
        j.setJarByClass(LabMapReduce.class);
        j.setNumReduceTasks(1); // Required for global rank continuity in the sorting exercise.
        switch (a[0]) {
            case "dedup":
                j.setMapperClass(DedupMapper.class); j.setCombinerClass(DedupReducer.class);
                j.setReducerClass(DedupReducer.class);
                j.setMapOutputKeyClass(Text.class); j.setMapOutputValueClass(NullWritable.class);
                j.setOutputKeyClass(Text.class); j.setOutputValueClass(NullWritable.class); break;
            case "sort":
                j.setMapperClass(SortMapper.class); j.setReducerClass(SortReducer.class);
                j.setMapOutputKeyClass(IntWritable.class); j.setMapOutputValueClass(NullWritable.class);
                j.setOutputKeyClass(LongWritable.class); j.setOutputValueClass(IntWritable.class); break;
            case "family":
                j.setMapperClass(FamilyMapper.class); j.setReducerClass(FamilyReducer.class);
                j.setMapOutputKeyClass(Text.class); j.setMapOutputValueClass(Text.class);
                j.setOutputKeyClass(Text.class); j.setOutputValueClass(Text.class); break;
            default: throw new IllegalArgumentException("Unknown job: " + a[0]);
        }
        FileInputFormat.addInputPath(j, new Path(a[1]));
        FileOutputFormat.setOutputPath(j, new Path(a[2]));
        if (!j.waitForCompletion(true)) System.exit(1);
    }
}
