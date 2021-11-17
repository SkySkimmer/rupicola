#/bin/sh
set -eu
cd "$(dirname "$0")"

( cd ../../../../
  COQFLAGS="${COQFLAGS:-"$(make -f Makefile.coqflags)"}" bedrock2/etc/bytedump.sh Rupicola.Examples.RevComp.revcomp_cbytes
  ) > revcomp_rupicola.c

CC="${CC:-cc}"

$CC -O3 -c revcomp_rupicola.c
$CC -O3 ubench.c revcomp_rupicola.o -lm -o ubench_rupicola

$CC -O3 -c revcomp_c.c
$CC -O3 ubench.c revcomp_c.o -lm -o ubench_c

doas /usr/local/bin/turboboost-off.sh > /dev/null
doas /usr/local/bin/hyperthreading-off.sh > /dev/null

#doas /usr/bin/cpupower -c 2 frequency-set --freq "$(grep -o '[0-9\.]*GHz' /proc/cpuinfo | sort -h | head -1)"
doas /usr/bin/cpupower -c 2 frequency-set --governor performance
sleep 1
printf "revcomp_rupicola: "; taskset -c 2 ./ubench_rupicola
printf "revcomp_c: "; taskset -c 2 ./ubench_rupicola
#doas /usr/bin/cpupower -c 2 frequency-set --governor schedutil

doas /usr/local/bin/hyperthreading-on.sh > /dev/null
doas /usr/local/bin/turboboost-on.sh > /dev/null
