#!/bin/bash
# Samu Firmware unpacker: .tar.md5 format

if  [ "$#" -ne 1 ]; then
  echo "Usage: ./samunpack filename.tar.md5"
  exit 1;
fi
if  [ ! -e $1 ]; then
  echo "File does not exist!"
  exit 1;
fi

# Check dependencies
command -v tar >/dev/null 2>&1 || { echo >&2 "Missing dependency: tar"; exit 1; }
command -v dd >/dev/null 2>&1 || { echo >&2 "Missing dependency: dd"; exit 1; }
command -v gunzip >/dev/null 2>&1 || { echo >&2 "Missing dependency: gzip"; exit 1; }
command -v cpio >/dev/null 2>&1 || { echo >&2 "Missing dependency: cpio"; exit 1; }

# untar
echo "Extracting tarfile:"
mkdir -p ./out && tar -xf $1 -C ./out

# Extract Recovery
cd out;
mkdir -p recovery;
echo "Extracting recovery.img:";
# Use abootimg if installed
if command -v abootimg &>/dev/null; then
  echo "[Using abootimg]"
  cd recovery && abootimg -x ../recovery.img
else
  echo "[Using DD]"
  # Get offsets for recovery
  let kernel_size="$(od -An -v -N 4 -t u4 -j 8 recovery.img)"
  let ramdisk_size="$(od -An -v -N 4 -t u4 -j 16 recovery.img)"
  let pagesize="$(od -An -v -N 4 -t u4 -j 36 recovery.img)"
  echo "Pagesize    : $pagesize"
  echo "Kernel size : $kernel_size"
  echo "Ramdisk size: $ramdisk_size"
  dd if=recovery.img of=recovery/zImage.bin bs=$pagesize count=$(($kernel_size/$pagesize+1)) skip=1 &> /dev/null
  dd if=recovery.img of=recovery/initrd.img bs=$pagesize count=$(($ramdisk_size/$pagesize+1)) skip=$((1+$kernel_size/$pagesize+1)) &> /dev/null
  # TODO: write a bootimg.cfg file compatible with abootimg
  cd recovery
fi

# Extract ramdisk
echo "Extracting recovery/ramdisk"
mkdir -p ramdisk && cd ramdisk
gunzip -c ../initrd.img | cpio -i
exit 0
