

class Main {

    public static inline var BENCHMARK_FILE_DIR = "res/bench/";
    public static var BENCHMARK_FILES = [
        "avo/Avocado.gltf",
    ];

    public static function main() {
        var totalTime = 0.0;
        for (filename in BENCHMARK_FILES) {
            Sys.print('Loading $filename ');
            var binary = switch (haxe.io.Path.extension(filename)) {
                case "glb":  true;
                case "gltf": false;
                case _: throw "bad extension";
            }

            var filepath = haxe.io.Path.join([BENCHMARK_FILE_DIR, filename]);
            var directory = haxe.io.Path.directory(filepath);
            var contents = hxd.File.getBytes(filepath);

            // relative to benchmark file dir
            var reldir = haxe.io.Path.directory(filename);

            try {
                var start = Sys.time();
                var hmd = Main.loadGltf(filename, directory, reldir, contents, binary);
                var duration = Sys.time() - start;

                Sys.println('(${duration}s)');
                totalTime += duration;
            } catch (e: Dynamic) {
                Sys.println(' ERROR: $e');
            }
        }

        var n = BENCHMARK_FILES.length;
        Sys.println('Loaded $n files in ${totalTime}s');
    }

    public static function loadGltf(
        filename: String,
        directory: String,
        reldir: String,
        content: haxe.io.Bytes,
        binary: Bool
    ): hxd.fmt.hmd.Data {
        var parseFunc = binary
            ? hxd.fmt.gltf.Parser.parseGLB
            : hxd.fmt.gltf.Parser.parseGLTF;
        var data = parseFunc(filename, directory, content);
        var hmd = hxd.fmt.gltf.HMDOut.emitHMD(filename, reldir, data);
        return hmd;
    }

}
