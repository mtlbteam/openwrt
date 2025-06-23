#!/bin/sh

ARCH=$(uname -m)

case "$ARCH" in
  aarch64)
    echo "arm64"
    ;;
  mips|mipsel)
    echo "mips"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

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

echo "All required modules are installed"
echo "Download bin"

# todo: download

if /etc/init.d/mtlb status | grep -q "running"; then
  echo "Stopping mtlb"
  /etc/init.d/mtlb stop
fi

echo "Create service"

cat << 'EOF' > /etc/init.d/mtlb
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
  procd_open_instance
  procd_set_param command /tmp/mtlb-bin
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