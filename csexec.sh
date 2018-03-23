#!/bin/bash

# https://stackoverflow.com/questions/20392243/run-c-sharp-code-on-linux-terminal

if [ ! -f "$1" ]; then
    mcs_args=$1
    shift
else
    mcs_args=""
fi
script=$1
shift
input_cs="$(mktemp)"
output_exe="$(mktemp)"
#tail -n +2 $script > $input_cs
cat $script > $input_cs
mcs $mcs_args $input_cs -out:${output_exe} -r:System.Net.Http.dll && mono $output_exe $@
rm -f $input_cs $output_exe
