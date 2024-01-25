# Heaps-glTF

Work in Progress. Forked from [cerastes](https://github.com/nspitko/cerastes/tree/main/cerastes/fmt/gltf)

## Usage

Simply include these two lines in your hxml:
```
-lib heaps-gltf
--macro hxd.fmt.gltf.Macros.build()
```

## Sample
`haxe sample.hxml && hl sample.hl`

## Resources

Avocado.gltf and related files are public domain assets from [glTF-Sample-Models](https://github.com/KhronosGroup/glTF-Sample-Models/).

## TODO

* figure out why the toy car model crashes (index exceeds uint16)
