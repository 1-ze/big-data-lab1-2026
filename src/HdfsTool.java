import java.io.*;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.*;
import org.apache.hadoop.io.IOUtils;

public class HdfsTool {
    private static FileSystem fs;
    private static void parents(Path p) throws IOException {
        Path parent = p.getParent();
        if (parent != null && !fs.mkdirs(parent) && !fs.isDirectory(parent))
            throw new IOException("Cannot create parent: " + parent);
    }
    private static void copy(InputStream in, OutputStream out) throws IOException {
        IOUtils.copyBytes(in, out, 65536, false);
    }
    private static void info(FileStatus s) {
        // HDFS FileStatus exposes modification/access times, not a general creation time.
        System.out.printf("%s\t%s:%s\t%d\tmtime=%s\t%s%n", s.getPermission(),
            s.getOwner(), s.getGroup(), s.getLen(), Instant.ofEpochMilli(s.getModificationTime()), s.getPath());
    }
    private static void upload(String local, Path remote, String mode) throws IOException {
        if (!mode.equals("append") && !mode.equals("overwrite") && !mode.equals("error"))
            throw new IllegalArgumentException("mode must be append, overwrite, or error");
        parents(remote);
        boolean exists = fs.exists(remote);
        if (exists && mode.equals("error")) throw new IOException("File exists; choose append or overwrite");
        try (InputStream in = new FileInputStream(local);
             OutputStream out = exists && mode.equals("append") ? fs.append(remote) : fs.create(remote, mode.equals("overwrite"))) {
            copy(in, out);
        }
        System.out.println("UPLOADED " + remote + " mode=" + mode);
    }
    private static void download(Path remote, String local) throws IOException {
        java.nio.file.Path requested = java.nio.file.Paths.get(local);
        java.nio.file.Path parent = requested.toAbsolutePath().getParent();
        java.nio.file.Files.createDirectories(parent);
        String base = requested.getFileName().toString();
        int dot = base.lastIndexOf('.');
        String stem = dot > 0 ? base.substring(0, dot) : base;
        String extension = dot > 0 ? base.substring(dot) : "";
        int suffix = 0;
        java.nio.file.Path target = requested;
        OutputStream out;
        while (true) {
            try { out = java.nio.file.Files.newOutputStream(target, java.nio.file.StandardOpenOption.CREATE_NEW); break; }
            catch (java.nio.file.FileAlreadyExistsException e) {
                target = requested.resolveSibling(stem + "_" + (++suffix) + extension);
            }
        }
        try (OutputStream stream = out; InputStream in = fs.open(remote)) { copy(in, stream); }
        System.out.println("DOWNLOADED " + target.toAbsolutePath());
    }
    private static void addText(Path file, String where, String text) throws IOException {
        byte[] data = text.getBytes(StandardCharsets.UTF_8);
        if (where.equals("tail")) {
            try (OutputStream out = fs.append(file)) { out.write(data); }
        } else if (where.equals("head")) {
            // HDFS supports append, but not inserting bytes at offset zero.
            String token = UUID.randomUUID().toString();
            Path temp = new Path(file.getParent(), ".prepend-" + token);
            Path backup = new Path(file.getParent(), ".backup-" + token);
            FileStatus old = fs.getFileStatus(file);
            try (InputStream in = fs.open(file); OutputStream out = fs.create(temp, false)) {
                out.write(data); copy(in, out);
            }
            fs.setPermission(temp, old.getPermission());
            if (!fs.rename(file, backup)) throw new IOException("Cannot stage original file");
            if (!fs.rename(temp, file)) {
                if (!fs.rename(backup, file)) throw new IOException("Replace and rollback failed; backup=" + backup);
                throw new IOException("Replace failed; original restored");
            }
            System.out.println("PREPEND_BACKUP " + backup);
        } else throw new IllegalArgumentException("where must be head or tail");
        System.out.println("APPENDED " + where + " " + file);
    }
    public static void main(String[] a) throws Exception {
        if (a.length < 2) throw new IllegalArgumentException(
            "upload LOCAL HDFS MODE | download HDFS LOCAL | cat PATH | stat PATH | list DIR | " +
            "create-file PATH | delete-file PATH | mkdir PATH | rmdir PATH | append PATH head|tail TEXT | move SRC DST");
        try (FileSystem fileSystem = FileSystem.get(new Configuration())) {
            fs = fileSystem;
            Path p = new Path(a[1]);
            switch (a[0]) {
                case "upload": upload(a[1], new Path(a[2]), a[3]); break;
                case "download": download(p, a[2]); break;
                case "cat": try (InputStream in = fs.open(p)) { copy(in, System.out); } break;
                case "stat": info(fs.getFileStatus(p)); break;
                case "list": {
                    RemoteIterator<LocatedFileStatus> files = fs.listFiles(p, true);
                    while (files.hasNext()) info(files.next());
                    break;
                }
                case "create-file": parents(p); try (OutputStream out = fs.create(p, false)) {} System.out.println("CREATED " + p); break;
                case "delete-file":
                    if (!fs.isFile(p)) throw new IOException("Not a file: " + p);
                    if (!fs.delete(p, false)) throw new IOException("Delete failed: " + p);
                    System.out.println("DELETED_FILE " + p); break;
                case "mkdir": if (!fs.mkdirs(p)) throw new IOException("mkdir failed: " + p); System.out.println("CREATED_DIR " + p); break;
                case "rmdir":
                    if (!fs.isDirectory(p)) throw new IOException("Not a directory: " + p);
                    if (fs.listStatus(p).length != 0) { System.out.println("REFUSED_NONEMPTY " + p); break; }
                    if (!fs.delete(p, false)) throw new IOException("rmdir failed: " + p);
                    System.out.println("DELETED_EMPTY_DIR " + p); break;
                case "append": addText(p, a[2], a[3]); break;
                case "move": {
                    Path dest = new Path(a[2]); parents(dest);
                    if (fs.exists(dest)) throw new IOException("Destination exists: " + dest);
                    if (!fs.rename(p, dest)) throw new IOException("Move failed: " + p);
                    System.out.println("MOVED " + p + " -> " + dest); break;
                }
                default: throw new IllegalArgumentException("Unknown operation: " + a[0]);
            }
        }
    }
}
