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

chmod +x $TMP1
chmod +x $TMP2

#echo "TMP1"
#cat $TMP1
#echo "TMP2"
#cat $TMP2

# FIXME: check for ignore_hole_birth tunable and change here

rm -f /dev/shm/pool[12]


# create pool tmpfiles and pools
dd if=/dev/zero of=/dev/shm/pool1 bs=1M count=1 seek=1024
dd if=/dev/zero of=/dev/shm/pool2 bs=1M count=1 seek=1024

zpool create pool1 /dev/shm/pool1
zpool create pool2 /dev/shm/pool2

zfs create pool1/fs1

# execute first steps
$TMP1

# create snap1
zfs snapshot pool1/fs1@snap1

# execute second steps
$TMP2

# create snap2
zfs snapshot pool1/fs1@snap2

# send snaps
zfs send pool1/fs1@snap1 | zfs recv pool2/fs1
zfs send -i pool1/fs1@snap{1,2} | zfs recv pool2/fs1

MD51=$(md5sum /pool1/fs1/file1 | awk '{ print $1 }')
MD52=$(md5sum /pool2/fs1/file1 | awk '{ print $1 }')

if [ "${MD51}" == "${MD52}" ]; then
	echo "No bug here."
else
	echo "MD5 ${MD51} doesn't match ${MD52}!";
	kill -ABRT $$;
fi

# cleanup
zpool destroy pool2
zpool destroy pool1
rm -f $TMP1
rm -f $TMP2

echo "Success."
