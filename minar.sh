#!/bin/bash

ETH() {
    cd $HOME/app/cpp-ethereum/build/ethminer
    #./ethminer --farm-recheck 200 -G -F http://127.0.0.1:8545
    ./ethminer --farm-recheck 200 -G -S eth-us-east1.nanopool.org:9999 -O 0x2a8535838d0d10E90ffcB36dd2E2788667B6c9C5.goku
}

XMR() {
    WALLET=44n1mbPYewv8uH8yBpTfWmZCGMXQY8Dh7FG6yDzE1qfdXf8Cn41WriETAPaUFMFxrvBQwaAsMxjeRgqQzdHs8pp6Jpxc5Zd
    $HOME/app/cpuminer-multi/minerd -a cryptonight -o stratum+tcp://pool.minexmr.com:4444 -u $WALLET.$(hostname) -p x
}

LUK() {
    WALLET=LKcniRJmQZ4chbV7n5Evj5WLvySxKxdk6NG92VsNgDZaT8G7JGAtpJFWgCdpvKG69gAsdzwDeqKaQMiKVRy8uaux8hFFHRu
    POOL=stratum01.cryptoluka.cl:7771
    #$DIR/app/cpuminer-multi/minerd -a cryptonight -o stratum+tcp://$POOL -u $WALLET.$(hostname) -p x
    $HOME/app/cpuminer-multi/minerd -a cryptonight -o stratum+tcp://$POOL -u $WALLET -p x
}

$1
