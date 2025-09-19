# pforret/leqm-nrt

## Description

`leqm-nrt` is a non-real-time implementation of Leq(M) measurement according to

* [ISO 21727:2004](leqm/iso_2004.md)(E): "Cinematography — Method of measurement of perceived loudness of motion-picture audio material" and
* [ISO 21727:2016](leqm/iso_2016.md)(E) "Cinematography — Method of measurement of perceived loudness of short duration motion-picture audio material"

## Usage

```
leqm-nrt  Copyright (C) 2011-2013, 2017-2020 Luca Trisciani
This program comes with ABSOLUTELY NO WARRANTY,
for details on command line parameters see --help
First argument is the audio file to be measured.
Other parameters can follow in free order.
This is free software, and you are welcome to redistribute it
under the GPL v3 licence.
Program will use 1 + 13 slave threads.
Order of parameters after audio file is free.
Possible parameters are:
--convpoints <integer number>   Use convolution with n points interpolation instead of polynomial filter.
Default is polynomial filter.
--numcpus <integer number>      Number of slave threads to speed up operation.
--timing                        For benchmarking speed.
--chconfcal <dB correction> <dB correction> <etc. so many times as channels>
--leqnw                         output leq with no weighting
--logleqm10                     (will also print Allen metric as output)
--lkfs                          Switch LKFS ITU 1770-4 on.
--dolbydi                       Switch Dolby Dialogue Intelligence on
--chgateconf <0|1|2>, 0 = no gate, 1 = level gate (in dB) and 2 = dialogue gate
--agsthreshold <speech %>       For Leq(M,DI) and LKFS(DI) default 33%.
--levelgate <Leq(M)>            This will force level gating and deactivate speech gating
--threshold <Leq(M)>            Threshold used for Allen metric (default 80)
--longperiod <minutes>          Long period for leqm10 (default 10)
--logleqm                       Log Leq(M) from start every buffersize ms.
--buffersize <milliseconds>                     Size of Buffer in milliseconds.
--truepeak                      Show true peak value
--oversampling <n>              Default: 4 times
--printdiinfo                   Show detailed speech intelligence information

Using:
gnuplot -e "plot \"logfile.txt\" u 1:2; pause -1"
it is possible to directly plot the logged data
```

## goqm - golang version of leqm-nrt

Converted to golang by Peter Forret & Codex CLI

Original code by Luca Trisciani - 2011-2013, 2017-2020
Forked by Peter Forret - 2024-2025

