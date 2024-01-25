package hxd.fmt.gltf;

import haxe.macro.Expr;


#if macro
import hxd.fmt.gltf.Convert;
import hxd.res.Config;
#end


class Macros {
    #if macro

    public static function build() {
        Config.extensions["glb,gltf"] = "hxd.res.Model";
    }

    public static function patchFunc(
        fields: Array<Field>,
        name: String,
        ?prepend: Expr,
        ?append: Expr,
        insertOldCode: Bool = true
    ): Void {
        for (f in fields) {
            if (f.name == name) switch(f.kind) {
                case FFun(f):
                    var block:Array<Expr> = insertOldCode ? asBlock(f.expr) : [];
                    if (prepend != null) block = asBlock(prepend).concat(block);
                    if (append != null) block = block.concat(asBlock(append));
                    f.expr = {
                        expr: EBlock(block),
                        pos: f.expr.pos
                    };
                default:
                    throw "Unexpected field type when patching a function!";
            }
        }
    }

    public static function asBlock(e: Expr): Array<Expr> {
        return switch (e.expr) {
            case EBlock(exprs): exprs;
            default: [e];
        }
    }

    public static function patchModelCache(): Array<Field> {
        var fields: Array<Field> = haxe.macro.Context.getBuildFields();
        // TODO: make this less bad
        //
        // glTF can embed materials as simply a color, but HMD does not support
        // this and requires all materials to be files. Instead of outputing new
        // material resources, I am patching h3d.prim.ModelCache to convert
        // these colors into materials on the fly.
        //
        // we're using the patchFunc utility above (thanks heeps) to prepend
        // this patch to ModelCache.loadTexture. However, this bypasses
        // the actual caching functionality later in the function.
        //
        var prepend = macro {
            if (texturePath.length == 7 && texturePath.charAt(0) == "#") {
                // this is a hex color code #xxxxxx

                // TODO: why does this cause compiler failure?
                // var color = "0x" + texturePath.substring(1);
                var color = "0x" + texturePath.split("#")[1];

                if (~/^0x[0-9A-Fa-f]*$/.match(color)) {
                    return h3d.mat.Texture.fromColor(Std.parseInt(color));
                }
            }
        };
        Macros.patchFunc(fields, "loadTexture", prepend);
        return fields;
    }

    #end
}
