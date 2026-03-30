#!/usr/bin/env bash
set -e

### CONFIG (8 Core / 16GB RAM / 32GB Disk) ###
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="server2012.iso"
DISK_FILE="ws2012.img"
DISK_SIZE="32G"
RAM="16G"
CORES="8"
VNC_PORT="5900"
FLAG_FILE="installed.flag"

echo "🚀 ĐANG KHỞI CHẠY WINDOWS SERVER 2012 (8 CORE / 16GB RAM)..."

# 0. Dọn dẹp tiến trình cũ để giải phóng RAM
pkill -9 -f qemu || true
pkill -9 -f bore || true

# 1. Tải QEMU System chuẩn (Bản Full tính năng, né lỗi smp và lỗi HTML)
if [ ! -f "./qemu-system-x86_64" ]; then
    echo "📥 Đang tải QEMU System (Bản chuẩn)..."
    # Tải từ nguồn build sẵn cực kỳ ổn định
    wget -qO qemu-system-x86_64 "https://github.com/minos-org/minos-static/raw/master/bin/qemu-system-x86_64"
    
    # Kiểm tra nếu tải nhầm file HTML thì xóa và dùng link dự phòng
    if grep -q "DOCTYPE" "./qemu-system-x86_64" 2>/dev/null; then
        rm -f qemu-system-x86_64
        echo "❌ Link lỗi, đang dùng link dự phòng..."
        curl -L "https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static" -o qemu-system-x86_64
    fi
    chmod +x qemu-system-x86_64
fi

# 2. Tạo ổ đĩa 32GB bằng lệnh hệ thống (Né lỗi qemu-img)
if [ ! -f "$DISK_FILE" ]; then
    echo "💾 Đang khởi tạo không gian đĩa $DISK_SIZE..."
    truncate -s "$DISK_SIZE" "$DISK_FILE"
fi

# 3. Tải ISO Windows (Nếu chưa có)
if [ ! -f "$FLAG_FILE" ] && [ ! -f "$ISO_FILE" ]; then
    echo "🌐 Đang tải ISO Windows (Vui lòng đợi)..."
    wget -qO "$ISO_FILE" "$ISO_URL"
fi

# 4. Cài đặt Bore Tunnel
if [ ! -f "./bore" ]; then
    echo "📥 Cài đặt Bore Tunnel..."
    curl -L "https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz" | tar -xz
    chmod +x bore
fi

# 5. Chạy Bore và in Link VNC
nohup ./bore local $VNC_PORT --to bore.pub > bore_vnc.log 2>&1 &
sleep 5
VNC_PUBLIC=$(grep -oE 'bore.pub:[0-9]+' bore_vnc.log | head -n 1)

echo "------------------------------------------"
echo "🌍 ĐỊA CHỈ VNC: $VNC_PUBLIC"
echo "👉 Dùng VNC Viewer kết nối vào địa chỉ trên."
echo "------------------------------------------"

# 6. Chạy QEMU
KVM_OPT="-cpu max"
[ -e /dev/kvm ] && KVM_OPT="-enable-kvm -cpu host"

if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️ CHẾ ĐỘ CÀI ĐẶT"
  ./qemu-system-x86_64 $KVM_OPT -smp "$CORES" -m "$RAM" \
    -drive file="$DISK_FILE",format=raw -cdrom "$ISO_FILE" \
    -vnc :0 -usb -device usb-tablet &
  
  while true; do
    read -rp "👉 Cài xong trên VNC thì nhập 'xong': " DONE
    if [ "$DONE" == "xong" ]; then
        touch "$FLAG_FILE"
        pkill -9 qemu
        echo "✅ Đã lưu! Lần sau sẽ boot thẳng vào Windows."
        exit 0
    fi
  done
else
  echo "✅ Đang Boot Windows Server 2012..."
  ./qemu-system-x86_64 $KVM_OPT -smp "$CORES" -m "$RAM" \
    -drive file="$DISK_FILE",format=raw -vnc :0 -nographic
fi
