"""Splice the test code into SNUGGLE.BAS and print the result (LF line endings).

--cases <window|controls|heap|apps|input|speed> picks the cases (the test code, the reference code
and the program share the 160 KB QBasic gives code and arrays, so the cases run
as separate programs).
With --smoke it prints SNUGGLE.BAS with a stop after the first paint instead; the
program writes the free memory (FRE(-1)) it has left at that point.

The program under test is the real SNUGGLE.BAS. Three things change:
  - the run section ('@@RUN-BEGIN .. '@@RUN-END) becomes the test body,
  - the drawing layer ('@@GFX-BEGIN .. '@@GFX-END) becomes a counting layer,
  - the palette setup is left out (the hit tests and the drag loops stay: the
    input group runs the main loop with a scripted mouse),
  - the mouse library ('@@MOUSE-BEGIN .. '@@MOUSE-END) becomes stubs: the test
    build needs the memory (see docs/APPS-AND-API.md), and the cases need no mouse,
  - the test globals, declares and subs are added.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
tests = root / "tests"
import importlib.util

_spec = importlib.util.spec_from_file_location("snuggle_build", root / "scripts" / "build.py")
_build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_build)

# The apps each group needs (the whole program does not fit in QBasic's memory
# together with the test code). The smoke and screenshot builds use all of them.
GROUP_APPS = {
    "window": ["hello"], "controls": ["hello"], "heap": ["hello"], "speed": ["hello"],
    "apps": ["clock", "calc", "flappy"], "input": ["hello", "calc", "notepad"],
}
_group = sys.argv[sys.argv.index("--cases") + 1] if "--cases" in sys.argv else None
if _group in GROUP_APPS:
    src = _build.build_text(GROUP_APPS[_group])
else:
    src = _build.build_text()


def part(name):
    return (tests / name).read_text().replace("\r\n", "\n")


def swap(text, begin, end, body):
    pattern = re.compile(r"^'@@%s\n.*?^'@@%s\n" % (begin, end), re.S | re.M)
    new, n = pattern.subn(lambda m: body.rstrip("\n") + "\n", text)
    if n != 1:
        sys.exit("build_test: marker '@@%s not found exactly once in SNUGGLE.BAS" % begin)
    return new


if "--shot" in sys.argv:
    # The program as shipped, except that it dumps the screen after its first
    # paint (SHOT0.BIN .. SHOT3.BIN, one file per bit plane) and stops.
    marker = "refresh\n\nDO\n"
    if src.count(marker) != 1:
        sys.exit("build_test: start of the main loop not found")
    dump = ("refresh\nFOR sp = 0 TO 3\nOUT &H3CE, 4\nOUT &H3CF, sp\nDEF SEG = &HA000\n"
            'BSAVE "SHOT" + CHR$(48 + sp) + ".BIN", 0, 38400\nDEF SEG\nNEXT\n'
            'OPEN "SHOT.TXT" FOR OUTPUT AS #1\nPRINT #1, "done"\nCLOSE #1\nSYSTEM\n\nDO\n')
    sys.stdout.write(src.replace(marker, dump))
    sys.exit(0)

if "--smoke" in sys.argv:
    # The program as shipped, except that it stops once its first paint is done.
    marker = "refresh\n\nDO\n"
    if src.count(marker) != 1:
        sys.exit("build_test: start of the main loop not found")
    sys.stdout.write(src.replace(marker, 'refresh\nOPEN "SMOKE.TXT" FOR OUTPUT AS #1\nPRINT #1, "started"; FRE(-1)\nCLOSE #1\nSYSTEM\n\nDO\n'))
    sys.exit(0)

out = swap(src, "RUN-BEGIN", "RUN-END", part("run_body.bas"))
out = swap(out, "GFX-BEGIN", "GFX-END", part("gfx.bas"))
out = swap(out, "MOUSE-BEGIN", "MOUSE-END", part("mouse_stub.bas"))
out = swap(out, "INIT-BEGIN", "INIT-END", "SUB Init\nCoutSetup\nEND SUB\n")

marker = "'***************\n"
if out.count(marker) < 1:
    sys.exit("build_test: declare marker not found")
out = out.replace(marker, part("declares.bas") + marker, 1)

if out.count("DEFINT A-Z\n") != 1:
    sys.exit("build_test: DEFINT A-Z not found exactly once")
out = out.replace("DEFINT A-Z\n", part("globals.bas") + "DEFINT A-Z\n", 1)

cases = "window"
if "--cases" in sys.argv:
    cases = sys.argv[sys.argv.index("--cases") + 1]
if not (tests / ("cases_%s.bas" % cases)).exists():
    sys.exit("build_test: no tests/cases_%s.bas" % cases)

for name in ("ref.bas", "lib.bas", "cases_%s.bas" % cases):
    out = out.rstrip("\n") + "\n\n" + part(name)

sys.stdout.write(out)
