#!/usr/bin/env sh
set -e
docker build -t snuggleos . && docker run --rm -p 8080:8080 snuggleos
