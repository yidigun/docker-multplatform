#!/bin/sh

cat /hello.txt

echo $(uname -o) $(uname -r)
echo ARCH=$(uname -m)

echo BASE_IMAGE=$BASE_IMAGE
echo BASE_VERSION=$BASE_VERSION
echo IMAGE_NAME=$IMAGE_NAME
echo IMAGE_TAG=$IMAGE_TAG
