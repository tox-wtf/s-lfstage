#!/bin/bash

# Create a limited directory layout
mkdir -pv "$LFS"/{etc,var,tools} "$LFS"/usr/{bin,lib}
for i in bin lib; do
    ln -sv "usr/$i" "$LFS/$i"
done
