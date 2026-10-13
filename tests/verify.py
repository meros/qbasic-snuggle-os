"""Compare the screen dumps a test run wrote and print PASS/FAIL per snapshot.

The QBasic test program writes, for every SNAP line in RESULT.TXT, the four bit
planes of side A (the incremental code) and side B (the 1999 reference) as
S<nnn><A|B><plane>.BIN (BSAVE files: a 7 byte header, then 38400 bytes).
Failing snapshots also get build/diff_<nnn>.png (A | B | differences).

usage: verify.py <build dir>     exit 1 when a snapshot differs
"""
import pathlib
import struct
import sys
import zlib

W, H, PLANE = 640, 480, 38400

# SCREEN 12 attribute -> DAC register (QBasic default), the EGA DAC defaults, and
# the registers Init changes with OUT &H3C8/&H3C9 (6 bit values).
ATTR_TO_DAC = [0, 1, 2, 3, 4, 5, 20, 7, 56, 57, 58, 59, 60, 61, 62, 63]
INIT_DAC = {0: (0, 0, 0), 1: (22, 22, 22), 2: (32, 32, 32), 3: (42, 42, 42),
            4: (0, 40, 40), 5: (0, 0, 22), 6: (0, 0, 32), 7: (0, 0, 42)}


def dac_rgb(i):
    if i in INIT_DAC:
        return tuple(round(v * 255 / 63) for v in INIT_DAC[i])
    r = (i >> 2 & 1) * 0xAA + (i >> 5 & 1) * 0x55
    g = (i >> 1 & 1) * 0xAA + (i >> 4 & 1) * 0x55
    b = (i & 1) * 0xAA + (i >> 3 & 1) * 0x55
    return (r, g, b)


PALETTE = [dac_rgb(d) for d in ATTR_TO_DAC]


def load(build, nnn, side):
    planes = []
    for p in range(4):
        data = (build / ("S%s%s%d.BIN" % (nnn, side, p))).read_bytes()
        if len(data) != PLANE + 7:
            raise ValueError("%s: %d bytes, expected %d" % (nnn + side, len(data), PLANE + 7))
        planes.append(data[7:])
    return planes


def pixels(planes):
    """Attribute number of every pixel, row-major."""
    out = bytearray(W * H)
    for row in range(H):
        base = row * 80
        for col in range(80):
            b0, b1, b2, b3 = (planes[0][base + col], planes[1][base + col],
                              planes[2][base + col], planes[3][base + col])
            for bit in range(8):
                m = 0x80 >> bit
                out[row * W + col * 8 + bit] = ((b0 & m) != 0) | (((b1 & m) != 0) << 1) | \
                    (((b2 & m) != 0) << 2) | (((b3 & m) != 0) << 3)
    return out


def png(path, width, height, rgb):
    raw = b"".join(b"\x00" + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def diff_image(path, a, b):
    out = bytearray()
    for y in range(H):
        ra, rb = a[y * W:(y + 1) * W], b[y * W:(y + 1) * W]
        for img in (ra, rb):
            for v in img:
                out += bytes(PALETTE[v])
        for x in range(W):
            out += b"\xff\x00\x00" if ra[x] != rb[x] else b"\x20\x20\x20"
    png(path, W * 3, H, bytes(out))


def main():
    build = pathlib.Path(sys.argv[1])
    snaps = []
    for line in (build / "RESULT.TXT").read_text().splitlines():
        if line.startswith("SNAP "):
            _, num, *label = line.split()
            snaps.append(("%03d" % int(num), " ".join(label)))
    failed = 0
    for nnn, label in snaps:
        try:
            a, b = pixels(load(build, nnn, "A")), pixels(load(build, nnn, "B"))
        except (OSError, ValueError) as e:
            print("FAIL %s: %s" % (label, e))
            failed += 1
            continue
        bad = [i for i in range(W * H) if a[i] != b[i]]
        if not bad:
            print("PASS %s" % label)
            continue
        failed += 1
        xs, ys = [i % W for i in bad], [i // W for i in bad]
        print("FAIL %s: %d pixels differ, x %d-%d, y %d-%d (see build/diff_%s.png)"
              % (label, len(bad), min(xs), max(xs), min(ys), max(ys), nnn))
        diff_image(build / ("diff_%s.png" % nnn), a, b)
    print("%d snapshot(s), %d differ" % (len(snaps), failed))
    sys.exit(1 if failed else 0)


main()
