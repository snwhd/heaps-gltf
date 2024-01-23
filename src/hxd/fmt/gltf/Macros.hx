package hxd.fmt.gltf;

#if macro
import hxd.res.Config;
#end


class Macros {

    #if macro
    public static function build() {
        Config.extends["glb,gltf"] = "hxd.res.Model";
    }
    #end

}
