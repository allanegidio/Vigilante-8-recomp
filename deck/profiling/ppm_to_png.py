"""Convert binary PPM (P6) captures to PNG, optionally downscaled, with no
third-party modules.

usage: python3 -I ppm_to_png.py [--half] <file.ppm> ... (writes <file>.png beside each)
"""
import struct
import sys
import zlib


def read_ppm(path):
    data = open(path, "rb").read()
    fields = []
    pos = 0
    while len(fields) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            pos = data.index(b"\n", pos) + 1
            continue
        end = pos
        while not data[end:end + 1].isspace():
            end += 1
        fields.append(data[pos:end])
        pos = end
    if fields[0] != b"P6" or int(fields[3]) != 255:
        raise ValueError(f"{path}: not an 8-bit P6 PPM")
    width, height = int(fields[1]), int(fields[2])
    pixels = data[pos + 1:pos + 1 + width * height * 3]
    return width, height, pixels


def half(width, height, pixels):
    out = bytearray()
    for y in range(0, height - 1, 2):
        row = y * width * 3
        for x in range(0, width - 1, 2):
            i = row + x * 3
            out += pixels[i:i + 3]
    return width // 2, height // 2, bytes(out)


def write_png(path, width, height, pixels):
    raw = b"".join(b"\x00" + pixels[y * width * 3:(y + 1) * width * 3] for y in range(height))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        handle.write(chunk(b"IEND", b""))


def main():
    args = sys.argv[1:]
    shrink = "--half" in args
    for path in (a for a in args if a != "--half"):
        image = read_ppm(path)
        if shrink:
            image = half(*image)
        target = path[:-4] + ".png" if path.endswith(".ppm") else path + ".png"
        write_png(target, *image)
        print(target)


if __name__ == "__main__":
    main()
