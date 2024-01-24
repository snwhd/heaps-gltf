package hxd.fmt.gltf;


#if macro
import hxd.fmt.gltf.Convert;
import hxd.res.Config;
#end


class Macros {

    #if macro
    public static function build() {
        Config.extensions["glb,gltf"] = "hxd.res.Model";
    }
    #end

}
