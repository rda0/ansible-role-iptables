#!/bin/bash

echo -e "*filter"
echo -e ":INPUT DROP"
echo -e ":FORWARD DROP"
if [[ "${allow_o_any}" != "true" ]]; then
  echo -e ":OUTPUT DROP"
else
  echo -e ":OUTPUT ACCEPT"
fi

echo -ne '\n'
