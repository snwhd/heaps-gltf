#!/usr/bin/env python3
import struct

FILENAME = 'test.bin'
F = open('test.bin', 'wb')


total_bytes = 0
chunk_size = 0


def write_float(f: float):
    global total_bytes
    global chunk_size
    F.write(struct.pack("<f", f))
    total_bytes += 4
    chunk_size += 4


def write_vec(*ff):
    global total_bytes
    global chunk_size
    for f in ff:
        write_float(f)


def write_uint16(i: int):
    global total_bytes
    global chunk_size
    F.write(struct.pack("<H", i))
    total_bytes += 2
    chunk_size += 2


# positions
write_vec(0.0, 0.0, 0.0)
write_vec(1.0, 0.0, 0.0)
write_vec(0.0, 1.0, 0.0)
write_vec(0.0, 1.0, 0.0)
write_vec(1.0, 0.0, 0.0)
write_vec(1.0, 1.0, 0.0)
print(f'6 pos: offset={total_bytes - chunk_size} size={chunk_size}')
chunk_size = 0

# normals
write_vec( 0,             -0.70710678118,  0.70710678118)
write_vec( 0.70710678118,  0,              0.7071067811)
write_vec( 0,              0.70710678118,  0.7071067811)
write_vec( 0,              0.70710678118,  0.7071067811)
write_vec( 0.70710678118,  0,              0.7071067811)
write_vec(-0.70710678118,  0,              0.707106781)
print(f'6 nrm: offset={total_bytes - chunk_size} size={chunk_size}')
chunk_size = 0

# uvs
write_vec(0, 0)
write_vec(1, 1)
write_vec(0, 1)
write_vec(0, 1)
write_vec(1, 1)
write_vec(1, 2)
print(f'6 uvs: offset={total_bytes - chunk_size} size={chunk_size}')
chunk_size = 0

if True:
    # indices
    write_uint16(0)
    write_uint16(1)
    write_uint16(2)
    
    write_uint16(3)
    write_uint16(4)
    write_uint16(5)
    print(f'6 ind: offset={total_bytes - chunk_size} size={chunk_size}')

F.close()
