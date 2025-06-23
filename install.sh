#!/bin/sh

ARCH=$(uname -m)
RELEASE_ARCH=""

case "$ARCH" in
  aarch64)
    RELEASE_ARCH="arm64"
    ;;
  mips|mipsel)
    RELEASE_ARCH="mips"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found, installing..."
  opkg update && opkg install curl
  if [ $? -ne 0 ]; then
    echo "Failed to install curl!"
    exit 1
  fi
fi

if ! command -v wget >/dev/null 2>&1; then
  echo "wget not found, installing..."
  opkg update && opkg install wget
  if [ $? -ne 0 ]; then
    echo "Failed to install wget!"
    exit 1
  fi
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found, installing..."
  opkg update && opkg install jq
  if [ $? -ne 0 ]; then
    echo "Failed to install jq!"
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

echo "All required modules are installed"
echo "Download bin"

ASSET_NAME="mtlb-${RELEASE_ARCH}"
API_URL="https://api.github.com/repos/mtlbteam/openwrt/releases"

RESPONSE=$(curl -s "$API_URL")

DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r \
  '.[0].assets[]? | select(.name == "'"$ASSET_NAME"'") | .browser_download_url')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ Asset '$ASSET_NAME' not found in latest release."
  exit 1
fi

echo $ASSET_NAME
echo $DOWNLOAD_URL

TARGET_PATH="/tmp/${ASSET_NAME}"

curl -L -o "$TARGET_PATH" "$DOWNLOAD_URL"
chmod +x "$TARGET_PATH"
echo "✅ Downloaded $ASSET_NAME"

if /etc/init.d/mtlb status | grep -q "running"; then
  echo "Stopping mtlb"
  /etc/init.d/mtlb stop
fi

echo "Create service"

cat << EOF > /etc/init.d/mtlb
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command ${TARGET_PATH}
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param respawn 5 5 10
  procd_set_param reload_signal HUP
  procd_set_param term_timeout 60
  procd_close_instance
}
EOF

echo "Start service"

chmod +x /etc/init.d/mtlb
/etc/init.d/mtlb start