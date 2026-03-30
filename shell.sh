#!/usr/bin/env bash
set -e

# --- Cấu hình ---
DISK_FILE="ws2012.img"
RAM="16G"
CORES="8"
VNC_PORT="5900"

echo "🚀 ĐANG KHỞI CHẠY..."
pkill -9 -f qemu || true
pkill -9 -f bore || true

# 1. Tải QEMU System chuẩn (Né lỗi 'smp')
if [ ! -f "./qemu-system-x86_64" ]; then
    echo "📥 Đang tải QEMU System chuẩn..."
    curl -L "https://github.com/minos-org/minos-static/raw/master/bin/qemu-system-x86_64" -o qemu-system-x86_64
    chmod +x qemu-system-x86_64
fi

# 2. Tạo đĩa nếu chưa có
[ -f "$DISK_FILE" ] || truncate -s 32G "$DISK_FILE"

# 3. Chạy Bore Tunnel
if [ ! -f "./bore" ]; then
    curl -L "https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz" | tar -xz
    chmod +x bore
fi
nohup ./bore local $VNC_PORT --to bore.pub > bore_vnc.log 2>&1 &
sleep 5
VNC_PUBLIC=$(grep -oE 'bore.pub:[0-9]+' bore_vnc.log | head -n 1)

echo "------------------------------------------"
echo "🌍 ĐỊA CHỈ VNC: $VNC_PUBLIC"
echo "------------------------------------------"

# 4. Chạy QEMU (Dùng bản chuẩn vừa tải)
./qemu-system-x86_64 -cpu max -smp "$CORES" -m "$RAM" \
  -drive file="$DISK_FILE",format=raw -cdrom server2012.iso \
  -vnc :0 -usb -device usb-tablet
