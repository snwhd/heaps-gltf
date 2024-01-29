package hxd.fmt.gltf;


class BytesWriter {

    var bytes: haxe.io.Bytes;
    var cursor = 0;
    var inc = 0;

    public var length (get, never) : Int;
    private function get_length() return this.cursor;

    private var remaining (get, never) : Int;
    private function get_remaining() return this.bytes.length - this.cursor;

    public function new(size: Int, ?inc: Int) {
        this.bytes = haxe.io.Bytes.alloc(size);
        if (inc != null) {
            this.inc = inc;
        } else {
            this.inc = 100000; // size;
        }
    }

    public inline function expand(size: Int) {
        var old = this.bytes;
        this.bytes = haxe.io.Bytes.alloc(this.bytes.length + size);
        this.bytes.blit(0, old, 0, this.cursor);
    }

    public inline function check(count: Int) {
        if (this.remaining < count) {
            this.expand(this.inc + count);
        }
    }

    public inline function copyBytes(
        source: haxe.io.Bytes,
        position: Int,
        count: Int = 1
    ): Void {
        this.check(count);
        this.bytes.blit(this.cursor, source, position, count);
        this.cursor += count;
    }

    public inline function writeByte(i: Int) {
        this.check(1);
        this.bytes.set(this.cursor++, i);
    }

    public inline function writeBytes(bytes: haxe.io.Bytes, offset: Int, length: Int) {
        this.copyBytes(bytes, offset, length);
    }

    public inline function copyFloats(
        source: haxe.io.Bytes,
        position: Int,
        count: Int = 1
    ): Void {
        this.copyBytes(source, position, count*4);
    }

    public inline function writeFloat(f: Float) {
        this.check(4);
        this.bytes.setFloat(this.cursor, f);
        this.cursor += 4;
    }

    public inline function writeInt32(i: Int) {
        this.check(4);
        this.bytes.setInt32(this.cursor, i);
        this.cursor += 4;
    }

    public inline function writeUInt16(i: Int) {
        this.check(2);
        this.bytes.setUInt16(this.cursor, i);
        this.cursor += 2;
    }

    public inline function getBytes() {
        return this.bytes.sub(0, this.length);
    }

}
