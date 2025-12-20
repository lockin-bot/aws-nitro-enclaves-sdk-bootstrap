#!/bin/bash
set -e
docker build --progress=plain -f Dockerfile.local --build-arg TARGET=kernel -t blobs_all .
docker rm extract_blobs &> /dev/null || true
docker create --name extract_blobs blobs_all
rm -rf blobs
docker cp extract_blobs:/blobs/ ./blobs
docker rm extract_blobs
