package hxd.fmt.gltf;


class GltfToHmd {

    private var parser: GltfParser;

    public function new(parser: GltfParser) {
        this.parser = parser;
    }

    public function toHMD(): hxd.fmt.hmd.Data {
        var outBytes = new haxe.io.BytesOutput();

        var models: Array<hxd.fmt.hmd.Data.Model> = [];
        var materials: Array<hxd.fmt.hmd.Data.Material> = [];
        var geometries: Array<hxd.fmt.hmd.Data.Geometry> = [];
        var animations: Array<hxd.fmt.hmd.Data.Animation> = [];

        //
        // build hmd data
        //

        var data = new hxd.fmt.hmd.Data();
        #if hmd_version
        data.version = Std.parseInt(
            #if macro
            haxe.macro.Context.definedValue("hmd_version")
            #else
            haxe.macro.Comiler.getDefine("hmd_version")
            #end
        );
        #else
        data.version = hxd.fmt.hmd.Data.CURRENT_VERSION;
        #end

        data.props = null;
        data.models = models;
        data.materials = materials;
        data.geometries = geometries;
        data.animations = animations;
        data.dataPosition = 0;
        data.data = outBytes.getBytes();
        return data;
    }

}
