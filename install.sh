#!/bin/sh

if ! command -v wget >/dev/null 2>&1; then
  echo "wget not found, installing..."
  opkg update && opkg install wget
  if [ $? -ne 0 ]; then
    echo "Failed to install wget!"
    exit 1
  fi
fi

REQUIRED_MODULES="kmod-ipt-tproxy kmod-nf-tproxy kmod-nft-tproxy"

for module in $REQUIRED_MODULES; do
  if ! opkg list-installed | grep -q "^$module "; then
    echo "$module not installed!"
    exit 1
  fi
done

echo "All required modules are installed."
echo "Download bin..."