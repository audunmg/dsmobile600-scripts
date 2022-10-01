#!/bin/sh

filename=$1
shift


/usr/bin/scanimage $@ > $filename
