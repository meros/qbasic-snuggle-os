# SNUGGLE.BAS, the QBasic program: the kernel and the apps joined by `snuggle`.
{ runCommand, tools }:
runCommand "snuggle-program" { nativeBuildInputs = [ tools ]; } ''
  mkdir -p $out
  snuggle build -o $out/SNUGGLE.BAS
''
