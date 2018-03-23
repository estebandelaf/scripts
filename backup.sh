#!/bin/bash
DIR_IN="/home/delaf/backup/disk1TB"
DIR_OUT="."
rsync -vv --human-readable --archive --copy-links --delete --progress $DIR_IN $DIR_OUT | grep -v uptodate
