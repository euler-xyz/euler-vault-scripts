#!/bin/bash

if [ ! -d "../euler-interfaces" ]; then
  cd .. && git clone https://github.com/euler-xyz/euler-interfaces.git && cd euler-vault-scripts
else
  cd ../euler-interfaces && git pull && cd ../euler-vault-scripts
fi

forge install
