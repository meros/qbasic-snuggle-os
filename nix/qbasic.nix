# QBASIC.EXE of Microsoft QBasic 1.1, out of the vendored archive. The archive
# is not free software (see the README): it is only unpacked, never changed.
{ runCommand, unzip }:
runCommand "qbasic-1.1" { nativeBuildInputs = [ unzip ]; } ''
  mkdir -p $out
  unzip -o -j ${../vendor/qb11.zip} QBASIC.EXE -d $out
''
