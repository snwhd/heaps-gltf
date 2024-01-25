# Testing Generated Tangents

Modeled on [mikktpy test](https://github.com/ambrusc/mikktpy/blob/master/test.py).
`test.gltf` defines a test mesh made up of two triangles. The binary portion can be
generated with `python3 test.py` which outputs `test.bin`.

`test.bin` will include embeded indices, which are pointed to by the gltf file. This
can be easily removed by deleting the `"indices": 3` line.

## Testing

TODO: make this a bit simpler

1. patch `HMDOut.hx` to print the x, y, z values of `generatedTangents`.
1. copy `test.gltf` and `test.bin` in `res/`
1. run `haxe sample.hl`
1. compare the printed tangents to `expected_values.txt`

