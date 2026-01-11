#!/bin/bash
set -e

# Build Verilator from source
cd /tmp
git clone https://github.com/verilator/verilator
cd verilator
unset VERILATOR_ROOT
git checkout v5.036
autoconf
./configure
make -j $(nproc)
make install
cd /
rm -rf /tmp/verilator
