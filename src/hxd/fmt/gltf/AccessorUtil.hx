package hxd.fmt.gltf;

import hxd.fmt.gltf.GltfData;


class AccessorUtil {

    public var accIndex: Int;
    public var count: Int;

    private var gltf: GltfData;
    private var bytes: haxe.io.Bytes;

    private var acc (get, never): GltfAccessor;
    private inline function get_acc() return this.gltf.accessors[this.accIndex];

    private var stride: Int;
    private var compSize: Int;
    public var typeSize: Int;
    private var byteOffset: Int;
    private var maxPos: Int;

    public inline function new(
        gltf: GltfData,
        glb: haxe.io.Bytes,
        index: Int,
        directory: String
    ) {
        this.accIndex = index;
        this.gltf = gltf;

        this.count = this.acc.count;

        var bufferView = gltf.bufferViews[this.acc.bufferView];
        var buffer = gltf.buffers[bufferView.buffer];

        this.bytes = AccessorUtil.readBuffer(buffer, glb, directory);

        if (this.bytes.length < buffer.byteLength) {
            throw "buffer too small";
        }

        this.compSize = switch (this.acc.componentType) {
            case BYTE:   1;
            case UBYTE:  1;
            case SHORT:  2;
            case USHORT: 2;
            case UINT:   4;
            case FLOAT:  4;
        };
        this.typeSize = switch (this.acc.type) {
            case SCALAR: 1;
            case VEC2:   2;
            case VEC3:   3;
            case VEC4:   4;
            case MAT2:   4;
            case MAT3:   9;
            case MAT4:  16;
        };
        this.stride = compSize * typeSize;
        if (bufferView.byteStride != null) {
            // TODO: only valid on some types
            this.stride = bufferView.byteStride;
        }

        var totalSize = this.acc.count * this.stride;
        if (totalSize > bufferView.byteLength) {
            throw "accessor too large";
        }

        var accOffset = 0;
        if (this.acc.byteOffset != null) {
            accOffset = this.acc.byteOffset;
        }
        var buffOffset = 0;
        if (bufferView.byteOffset != null) {
            buffOffset = bufferView.byteOffset;
        }

        this.byteOffset = buffOffset + accOffset;
        this.maxPos = this.byteOffset + totalSize;
        if (this.maxPos > buffer.byteLength) {
            throw "accessor/bufferview too large";
        }
    }

    public inline function float(i: Int, offset=0): Float {
        if (this.acc.componentType != FLOAT) throw "not a float buffer";
        var pos = this.byteOffset + (i * this.stride) + offset*4;
        if (pos >= maxPos) throw "out of bounds";
        return this.bytes.getFloat(pos);
    }

    public inline function index(i: Int): Int {
        return this.int(i);
    }

    public inline function int(i: Int, offset=0): Int {
        var pos = this.byteOffset + (i*this.stride) + offset*this.compSize;
        if (pos >= maxPos) throw "out of bounds";
        return switch (this.acc.componentType) {
            case BYTE:   this.bytes.get(pos); // TODO: signed?
            case UBYTE:  this.bytes.get(pos);
            case SHORT:  this.bytes.getUInt16(pos); // TODO: signed?
            case USHORT: this.bytes.getUInt16(pos);
            case UINT:   this.bytes.getInt32(pos);
            case FLOAT:  throw "not an intaccessor";
        }
    }

    public static function readBuffer(
        buffer: GltfBuffer,
        glb: haxe.io.Bytes,
        directory: String
    ): haxe.io.Bytes {
        var uri = buffer.uri;
        if (uri == null) {
            // null buffer -> glb chunk
            // TODO: if (bufferView.buffer != 0) throw "glb chunk != 0";
            if (glb == null) throw "missing glb chunk";
            return glb;
        } else if (~/^data:(.*);base64,/.match(uri.substr(0, 60))) {
            var dataStart = uri.indexOf(";base64,") + 8;
            return haxe.crypto.Base64.decode(uri.substr(dataStart));
        } else {
            #if sys
            return sys.io.File.getBytes(
                haxe.io.Path.join([directory, uri])
            );
            #else
            throw "TODO";
            #end
        }
    }

}
