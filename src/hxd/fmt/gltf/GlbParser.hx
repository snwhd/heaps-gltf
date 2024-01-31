package hxd.fmt.gltf;


class GlbParser {

    public static inline var MAGIC = "glTF";
    public static inline var JSON_TYPE = "JSON";

    public var version: Int;
    public var jsonString: String;
    public var binaryChunk: haxe.io.Bytes;

    public function new(bytes: haxe.io.Bytes) {
        var magic = bytes.getString(0, MAGIC.length);
        if (magic != MAGIC) throw "invalid magic, not a gltf file?";

        this.version = bytes.getInt32(4);
        if (this.version != 2) throw "unsupported glTf version (expected 2)";

        var fileLength = bytes.getInt32(8);
        if (fileLength > bytes.length) throw "file length mismatch";

        var jsonChunkStart = 12;
        var jsonChunkLength = bytes.getInt32(jsonChunkStart);
        if (fileLength < jsonChunkStart + 8 + jsonChunkLength) {
            throw "file length/json mismatch";
        }

        var jsonType = bytes.getString(jsonChunkStart+4, 4);
        if (jsonType != JSON_TYPE) throw "json type mismatch";
        this.jsonString = bytes.getString(jsonChunkStart+8, jsonChunkLength);

        // optional binary chunk
        var binChunkStart = jsonChunkStart + jsonChunkLength + 8;
        if (binChunkStart < fileLength) {
            var binChunkLength = bytes.getInt32(binChunkStart);
            if (fileLength < binChunkStart + 8 + binChunkLength) {
                throw "file length/binary length mismatch";
            }
            var binType = bytes.getString(binChunkStart+4, 3);
            if (binType != "BIN") throw "binary type mismatch";
            this.binaryChunk = bytes.sub(binChunkStart+8, binChunkLength);
        }
    }

}
