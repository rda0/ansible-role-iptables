#!/bin/bash

echo -e "*nat"
echo -e ":PREROUTING ACCEPT"
echo -e ":INPUT ACCEPT"
echo -e ":OUTPUT ACCEPT"
echo -e ":POSTROUTING ACCEPT"

echo -ne '\n'
