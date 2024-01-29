

class Main {

    public static inline var BENCHMARK_FILE_DIR = "res/bench/";
    public static var BENCHMARK_FILES = [
        "avo/Avocado.gltf",
        "water/WaterBottle.gltf",
        "car/ToyCar.gltf",
    ];

    public static inline var REPS = 10;

    public static function main() {

        var totalTime = 0.0;
        for (filename in BENCHMARK_FILES) {
            Sys.print('Loading $filename ');

            var version = "1";
            if (Sys.args().length > 0) {
                version = Sys.args()[0];
            }

            var duration = 0.0;

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

            for (i in 0 ... REPS) {
                try {
                    var start = Sys.time();
                    var hmd = switch (version) {
                        case "1": Main.loadGltfV1(filename, directory, reldir, contents, binary);
                        case "2": Main.loadGltfV2(filename, directory, reldir, contents, binary);
                        case _: throw "bad version";
                    }
                    var dur = Sys.time() - start;
                    totalTime += dur;
                    duration += dur;
                } catch (e: Dynamic) {
                    Sys.println(' ERROR: $e');
                    return;
                }
            }

            var avg = duration / REPS;
            Sys.println('(${avg}s)');
        }

        var n = BENCHMARK_FILES.length;
        Sys.println('Loaded $n files (x$REPS) in ${totalTime}s');
    }

    public static function loadGltfV1(
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

    public static function loadGltfV2(
        filename: String,
        directory: String,
        reldir: String,
        src: haxe.io.Bytes,
        binary: Bool
    ): hxd.fmt.hmd.Data {
        var content = src.getString(0, src.length);
        var convert = new hxd.fmt.gltf.GltfToHmd(filename, directory, reldir, content, null);
        return convert.toHMD();
    }

}
