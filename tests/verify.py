"""Compare the screen dumps a test run wrote and print PASS/FAIL per snapshot.

The QBasic test program writes, for every SNAP line in RESULT.TXT, the four bit
planes of side A (the incremental code) and side B (the 1999 reference) as
S<nnn><A|B><plane>.BIN (BSAVE files: a 7 byte header, then 38400 bytes).
Failing snapshots also get build/diff_<nnn>.png (A | B | differences).

usage: verify.py <build dir>     exit 1 when a snapshot differs
       verify.py --render <build dir> <prefix> <out.png>
"""
import pathlib
import struct
import sys
import zlib

W, H, PLANE = 640, 480, 38400

# SCREEN 12 colours. Attribute n uses DAC register n (read back from the attribute
# controller in QBasic 1.1 under DOSBox). QBasic's default values for registers
# 8 to 15, and for 0 to 7 the values SNUGGLE.BAS sets in Init (6 bit per channel).
DAC = [(0, 0, 0), (22, 22, 22), (32, 32, 32), (42, 42, 42), (0, 40, 40), (0, 0, 22), (0, 0, 32), (0, 0, 42),
       (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63), (63, 21, 21), (63, 21, 63), (63, 63, 21), (63, 63, 63)]
PALETTE = [tuple(round(c * 255 / 63) for c in rgb) for rgb in DAC]


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


def render(build, prefix, out):
    """Write <prefix>0.BIN .. <prefix>3.BIN (BSAVE dumps of the four planes) as a PNG."""
    planes = [(build / ("%s%d.BIN" % (prefix, p))).read_bytes()[7:] for p in range(4)]
    rgb = bytearray()
    for v in pixels(planes):
        rgb += bytes(PALETTE[v])
    png(pathlib.Path(out), W, H, bytes(rgb))


def main():
    if sys.argv[1] == "--render":
        render(pathlib.Path(sys.argv[2]), sys.argv[3], sys.argv[4])
        return
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
        if label.startswith("look"):
            rgb = bytearray()
            for v in a:
                rgb += bytes(PALETTE[v])
            png(build / ("look_%s.png" % nnn), W, H, bytes(rgb))
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
