package hxd.fmt.gltf;


typedef MapVal = { ints:Array<Int>, index:Int};


class SeqIntMap {

    static final PRIME_LIST = [13,29,41,59,73,101,113];

    var map: Map<Int, MapVal >;
    var invMap: Array<Int>;
    var hits = 0;
    var misses = 0;
    var colls = 0;

    public var count(get, never): Int;

    public function get_count() {
        return invMap.length;
    }

    public function new() {
        map = new Map();
        invMap = [];
    }

    private static inline function hashList(ints: Array<Int>) {
        // If this assert triggers, add more primes to the list
        if (ints.length > PRIME_LIST.length) throw "need more primes";
        var hash = 0;
        for (i in 0 ... ints.length) {
            hash += ints[i] * PRIME_LIST[i];
        }
        return hash;
    }

    private inline function listSame(a: Array<Int>, b: Array<Int>) {
        var res = true;
        if (a.length != b.length) res = false;
        else {
            for (i in 0...a.length) {
                if (a[i] != b[i]) {
                    res = false;
                    break;
                }
            }
        }
        return res;
    }

    public function add(ints: Array<Int>): Int {
        var pos = hashList(ints);
        while (true) {
            var val = map[pos];
            if (val == null) {
                var ind = invMap.length;
                map[pos] = {ints:ints, index:ind};
                invMap.push(pos);
                misses++;
                return ind;
            }
            if (this.listSame(ints, val.ints)) {
                hits++;
                return val.index;
            }
            colls++;
            pos++;
        }
        throw "Logic Error";
        return -1;
     }

    // reverse of 'add' function
    public function getList(ind:Int): Array<Int> {
        if (ind >= invMap.length) throw "bad index";
        var pos = invMap[ind];
        return map[pos].ints;
    }

    public function debugInfo() {
        trace('Hits: $hits Misses: $misses Collision: $colls');
    }
}
