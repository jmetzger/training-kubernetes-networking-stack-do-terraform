#!/bin/bash

# Wait silently until the file exists and is non-empty
while [ ! -s ./ingress_ip.txt ]; do
  sleep 1
done

cat ./ingress_ip.txt
