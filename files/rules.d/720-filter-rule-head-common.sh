#!/bin/bash

echo -e "-N i-deny"
[[ "${allow_o_any}" != "true" ]] && echo -e "-N o-deny"
echo -e "-N f-deny"

echo -ne '\n'
