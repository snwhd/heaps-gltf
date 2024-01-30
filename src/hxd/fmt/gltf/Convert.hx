package hxd.fmt.gltf;


typedef ParseFunction = (String, String, haxe.io.Bytes) -> hxd.fmt.gltf.Data;


@:keep
class ConvertGLTF2HMD extends hxd.fs.Convert {

    private var parseFunc: ParseFunction;

    public function new(binary: Bool) {
        #if heaps_gltf_use_v2
        if (binary) throw "TODO: support glb";
        super("gltf", "hmd");
        #else
        this.parseFunc = binary ?
            hxd.fmt.gltf.Parser.parseGLB :
            hxd.fmt.gltf.Parser.parseGLTF;
        super(binary ? "glb" : "gltf", "hmd");
        #end
    }

    override function convert() {
        #if heaps_gltf_use_v2
        this.convertV2();
        #else
        this.convertV1();
        #end
    }

    #if heaps_gltf_use_v2

    private function convertV2() {
        var filename = haxe.io.Path.withoutDirectory(this.srcPath);
        var filepath = haxe.io.Path.directory(this.srcPath);

        // Find the path relative to the asset's dir
        #if macro
        var directory = haxe.macro.Context.definedValue("resourcesPath");
        #else
        var directory = haxe.macro.Compiler.getDefine("resourcesPath");
        #end
        if (directory == null) directory = "res";
        var pos = this.srcPath.indexOf('/$directory/');
        if (pos == -1) {
            throw "path not relative to resource dir?";
        }
        var relpath = filepath.substr(pos + directory.length + 2);

        // TODO: glb
        var content = this.srcBytes.getString(0, this.srcBytes.length);
        var convert = new GltfToHmd(
            filename,
            filepath,
            relpath,
            content,
            null // TODO: glb
        );
        var hmd = convert.toHMD();
        var out = new haxe.io.BytesOutput();
        new hxd.fmt.hmd.Writer(out).write(hmd);
        this.save(out.getBytes());
    }

    #else

    private function convertV1() {
        var filename = haxe.io.Path.withoutDirectory(this.srcPath);
        var filepath = haxe.io.Path.directory(this.srcPath);

        // Find the path relative to the asset's dir
        #if macro
        var directory = haxe.macro.Context.definedValue("resourcesPath");
        #else
        var directory = haxe.macro.Compiler.getDefine("resourcesPath");
        #end
        if (directory == null) directory = "res";
        var pos = this.srcPath.indexOf('/$directory/');
        if (pos == -1) {
            throw "path not relative to resource dir?";
        }
        var relpath = filepath.substr(pos + directory.length + 2);

        // read/parse gltf and output hmd
        var data = this.parseFunc(filename, filepath, this.srcBytes);
        var hmd = HMDOut.emitHMD(filename, relpath, data);
        var out = new haxe.io.BytesOutput();
        new hxd.fmt.hmd.Writer(out).write(hmd);
        this.save(out.getBytes());
    }

    #end

    // TODO: why is this hack needed
    #if (sys || nodejs)
    static var __ = hxd.fs.FileConverter.addConfig({
        "fs.convert": {
            "gltf": { "convert" : "hmd", "priority" : -1 },
            "glb": { "convert" : "hmd", "priority" : -1 },
        }
    });
    #end

    #if !heaps_gltf_use_v2
    // TODO: support glb in v2
    static var glbConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(true));
    #end
    static var gltfConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(false));

}
