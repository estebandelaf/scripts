#!/bin/bash

wget \
	--recursive \
	--no-clobber \
	--page-requisites \
	--html-extension \
	--convert-links \
	--restrict-file-names=windows \
	--domains $2 \
	--no-parent \
	$1
