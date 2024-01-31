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
    private var totalSize: Int;

    public inline function new(
        gltf: GltfData,
        glb: haxe.io.Bytes,
        index: Int,
        directory: String
    ) {
        this.accIndex = index;
        this.gltf = gltf;

        this.count = this.acc.count;
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

        var bufferView = gltf.bufferViews[this.acc.bufferView];
        var buffer = gltf.buffers[bufferView.buffer];

        this.stride = compSize * typeSize;
        if (bufferView.byteStride != null) {
            // TODO: only valid on some types
            this.stride = bufferView.byteStride;
        }

        // equal to the index of the last allowed entry
        this.totalSize = this.acc.count * this.stride;
        if (this.totalSize > bufferView.byteLength) {
            throw "accessor larger than buffer view";
        }

        this.bytes = AccessorUtil.readBufferView(
            bufferView,
            buffer,
            glb,
            directory,
            this.acc.byteOffset == null ? 0 : this.acc.byteOffset
        );

        if (this.bytes.length < this.totalSize) {
            throw "buffer too small";
        }
    }

    public inline function copyFloats(out: BytesWriter, i: Int, count=1) {
        // TODO: only works if stride == 4
        if (this.acc.componentType != FLOAT) throw "not a float buffer";
        var pos = i * this.stride;
        if (pos >= totalSize) throw "out of bounds";
        out.copyFloats(this.bytes, pos, count);
    }

    public inline function float(i: Int, offset=0): Float {
        if (this.acc.componentType != FLOAT) throw "not a float buffer";
        var pos = (i * this.stride) + offset*4;
        if (pos >= totalSize) throw "out of bounds";
        return this.bytes.getFloat(pos);
    }

    public inline function index(i: Int): Int {
        return this.int(i);
    }

    public inline function int(i: Int, offset=0): Int {
        var pos = (i*this.stride) + offset*this.compSize;
        if (pos >= totalSize) throw "out of bounds";
        return switch (this.acc.componentType) {
            case BYTE:   this.bytes.get(pos); // TODO: signed?
            case UBYTE:  this.bytes.get(pos);
            case SHORT:  this.bytes.getUInt16(pos); // TODO: signed?
            case USHORT: this.bytes.getUInt16(pos);
            case UINT:   this.bytes.getInt32(pos);
            case FLOAT:  throw "not an intaccessor";
        }
    }

    public inline function matrix(i: Int): h3d.Matrix {
        if (this.acc.componentType != FLOAT) throw "not a float accessor";
        if (this.acc.type != MAT4) throw "not a mat4 accessor";
        if (i*64 + 15*4 >= totalSize) throw "out of bounds";

        var floats = [];
        floats.resize(16);
        for (j in 0 ... 16) {
            floats[j] = this.bytes.getFloat(i*64 + j*4);
        }
        var invBind = new h3d.Matrix();
        invBind._11 = floats[ 0];
        invBind._12 = floats[ 1];
        invBind._13 = floats[ 2];
        invBind._14 = floats[ 3];
        invBind._21 = floats[ 4];
        invBind._22 = floats[ 5];
        invBind._23 = floats[ 6];
        invBind._24 = floats[ 7];
        invBind._31 = floats[ 8];
        invBind._32 = floats[ 9];
        invBind._33 = floats[10];
        invBind._34 = floats[11];
        invBind._41 = floats[12];
        invBind._42 = floats[13];
        invBind._43 = floats[14];
        invBind._44 = floats[15];
        return invBind;
    }

    public static function readBufferView(
        view: GltfBufferView,
        buffer: GltfBuffer,
        glb: haxe.io.Bytes,
        directory: String,
        offset: Int = 0
    ): haxe.io.Bytes {
        var uri = buffer.uri;

        var start = offset;
        if (view.byteOffset != null) {
            start += view.byteOffset;
        }

        var length = view.byteLength - offset;

        var bytes: haxe.io.Bytes;
        if (uri == null) {
            // null buffer -> glb chunk
            // TODO: if (bufferView.buffer != 0) throw "glb chunk != 0";
            if (glb == null) throw "missing glb chunk";
            bytes = glb;
        } else if (~/^data:(.*);base64,/.match(uri.substr(0, 60))) {
            var dataStart = uri.indexOf(";base64,") + 8;
            bytes = haxe.crypto.Base64.decode(uri.substr(dataStart));
        } else {
            #if sys
            bytes = sys.io.File.getBytes(
                haxe.io.Path.join([directory, uri])
            );
            #else
            throw "TODO";
            #end
        }
        return bytes.sub(start, length);
    }

}
