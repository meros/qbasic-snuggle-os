"""Splice the test code into SNUGGLE.BAS and print the result (LF line endings).

With --smoke it prints SNUGGLE.BAS with a stop after the first paint instead.

The program under test is the real SNUGGLE.BAS. Three things change:
  - the run section ('@@RUN-BEGIN .. '@@RUN-END) becomes the test body,
  - the drawing layer ('@@GFX-BEGIN .. '@@GFX-END) becomes a counting layer,
  - the test globals, declares and subs are added.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
tests = root / "tests"
src = (root / "SNUGGLE.BAS").read_text().replace("\r\n", "\n")


def part(name):
    return (tests / name).read_text().replace("\r\n", "\n")


def swap(text, begin, end, body):
    pattern = re.compile(r"^'@@%s\n.*?^'@@%s\n" % (begin, end), re.S | re.M)
    new, n = pattern.subn(lambda m: body.rstrip("\n") + "\n", text)
    if n != 1:
        sys.exit("build_test: marker '@@%s not found exactly once in SNUGGLE.BAS" % begin)
    return new


if "--smoke" in sys.argv:
    # The program as shipped, except that it stops once its first paint is done.
    marker = "refresh\n\nDO\n"
    if src.count(marker) != 1:
        sys.exit("build_test: start of the main loop not found")
    sys.stdout.write(src.replace(marker, 'refresh\nOPEN "SMOKE.TXT" FOR OUTPUT AS #1\nPRINT #1, "started"\nCLOSE #1\nSYSTEM\n\nDO\n'))
    sys.exit(0)

out = swap(src, "RUN-BEGIN", "RUN-END", part("run_body.bas"))
out = swap(out, "GFX-BEGIN", "GFX-END", part("gfx.bas"))

marker = "'***************\n"
if out.count(marker) < 1:
    sys.exit("build_test: declare marker not found")
out = out.replace(marker, part("declares.bas") + marker, 1)

if out.count("DEFINT A-Z\n") != 1:
    sys.exit("build_test: DEFINT A-Z not found exactly once")
out = out.replace("DEFINT A-Z\n", part("globals.bas") + "DEFINT A-Z\n", 1)

for name in ("ref.bas", "lib.bas", "cases.bas"):
    out = out.rstrip("\n") + "\n\n" + part(name)

sys.stdout.write(out)
