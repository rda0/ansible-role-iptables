#!/bin/bash

echo -e "*mangle"
echo -e ":PREROUTING ACCEPT"
echo -e ":INPUT ACCEPT"
echo -e ":FORWARD ACCEPT"
echo -e ":OUTPUT ACCEPT"
echo -e ":POSTROUTING ACCEPT"

echo -ne '\n'
