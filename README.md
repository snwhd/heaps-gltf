# Heaps-glTF

Work in Progress. Forked from [cerastes](https://github.com/nspitko/cerastes/tree/main/cerastes/fmt/gltf)

## v2

The gltf -> hmd conversion has been signficantly rewritten. The new
implementation is in `GltfToHmd.hx` and `GltfData.hx` replacing the old
versions in `Data.hx`, `Parser.hx`, and `HMDOut.hx`.

V2 was primarily created to clean up the code and avoid intermediate steps
between gltf parsing and hmd output. It is also a bit faster than v1.

* in gltf files without tangents, v2 is ~41% faster than v1.
* in gltf files with embedded tangents (no need to run mikkt) v2 is ~18% faster.
* ~65% of time is spent running mikktspace when needed
* ~13% of time is spent reading input files
* take these numbers with a grain of salt, the benchmarking is not thorough yet.

Add `-D heaps_gltf_use_v2` to your hxml to use V2.


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
