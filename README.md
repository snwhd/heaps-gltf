# Heaps-glTF

Work in Progress. Forked from [cerastes](https://github.com/nspitko/cerastes/tree/main/cerastes/fmt/gltf)

## Usage

Simply include these two lines in your hxml:
```
-lib heaps-gltf
--macro hxd.fmt.gltf.Macros.build()
--macro addMetadata('@:build(hxd.fmt.gltf.Macros.patchModelCache())', 'h3d.prim.ModelCache')
```

### Embedded color materials

The second macro is only needed for some gltf files:

Gltf allows embedding materials simply as colors, which is not supported by
HMD. So, there's some gross patching of heaps going on here. See Macros.hx.

If you want prefer to completely ignore these materials, then add
`-D heaps_gltf_disable_material_color` to your hxml. This will prevent the
glTF to HMD conversion from outputting the materials. You will also need to
clear the resource cache for any gltf files embedding these materials.

## Sample
`haxe sample.hxml && hl build/sample.hl`

## Resources

Avocado.gltf and other example resources are public domain assets
from [glTF-Sample-Models](https://github.com/KhronosGroup/glTF-Sample-Models/).
