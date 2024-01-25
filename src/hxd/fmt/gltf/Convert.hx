package hxd.fmt.gltf;


typedef ParseFunction = (String, String, haxe.io.Bytes) -> hxd.fmt.gltf.Data;


@:keep
class ConvertGLTF2HMD extends hxd.fs.Convert {

    private var parseFunc: ParseFunction;

    public function new(binary: Bool) {
        this.parseFunc = binary ?
            hxd.fmt.gltf.Parser.parseGLB :
            hxd.fmt.gltf.Parser.parseGLTF;
        super(binary ? "glb" : "gltf", "hmd");
    }

    override function convert() {
        var filename = haxe.io.Path.withoutDirectory(this.srcPath);
        var filepath = haxe.io.Path.directory(this.srcPath);

        // Find the path relative to the asset's dir
        // TODO: rename to resdir or something
        var directory = haxe.macro.Context.definedValue("resourcesPath");
        if (directory == null) directory = "res";
        var pos = this.srcPath.indexOf('/$directory/');
        if (pos == -1) {
            trace(filepath);
            trace(this.srcPath);
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

    // TODO: why is this hack needed
    #if (sys || nodejs)
    static var __ = hxd.fs.FileConverter.addConfig({
        "fs.convert": {
            "gltf": { "convert" : "hmd", "priority" : -1 },
        }
    });
    #end

    static var glbConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(true));
    static var gltfConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(false));

}
