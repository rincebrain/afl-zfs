#!/bin/bash
INPUT_FILE=$1
TMP1=$(mktemp /tmp/afl_zfs.XXXXXX)
TMP2=$(mktemp /tmp/afl_zfs.XXXXXX)

# check input for existence and sanity 

if [ "$INPUT_FILE" == "" ] ||  [ ! -f $INPUT_FILE ]; then
	echo "Input file not present."
	exit 0;
fi

# we want exactly 1 delimiter, no more or less
if [ "$(grep -- '===' $INPUT_FILE | wc -l)" != "1" ]; then
	exit 0;
fi

grep -B 99 -- '===' $INPUT_FILE | head -n -1 > $TMP1
grep -A 99 -- '===' $INPUT_FILE | tail -n +2 > $TMP2

# create pool tmpfiles and pools
echo dd if=/dev/zero of=/dev/shm/pool1 bs=1M count=1 seek=1024
echo dd if=/dev/zero of=/dev/shm/pool2 bs=1M count=1 seek=1024

echo zpool create pool1 /dev/shm/pool1
echo zpool create pool2 /dev/shm/pool2

echo zfs create pool1/fs1

# execute first steps
cat $TMP1

# create snap1
echo zfs snapshot pool1/fs1@snap1

# execute second steps
cat $TMP2

# create snap2
echo zfs snapshot pool1/fs1@snap2

# send snaps
echo 'zfs send pool1/fs1@snap1 | zfs recv pool2/fs1'
echo 'zfs send -i pool1/fs1@snap{1,2} | zfs recv pool2/fs1'

