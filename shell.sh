#!/usr/bin/env bash
set -e

### CONFIG ###
# Link Windows Server 2012 bạn cung cấp
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="server2012.iso"

# Đổi sang thư mục home để tránh lỗi quyền ghi (Permission denied)
DISK_FILE="$HOME/ws2012.qcow2"
DISK_SIZE="32G"

# Cấu hình theo yêu cầu của bạn
RAM="16G"
CORES="8"

VNC_PORT="5900"
FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-idx"

### DỌN DẸP TRƯỚC KHI CHẠY ###
echo "🧹 Đang dọn dẹp các tiến trình cũ..."
pkill -9 -f qemu-system-x86_64 || true
pkill -9 -f bore || true

### CHECK KVM ###
[ -e /dev/kvm ] || { echo "❌ Không có /dev/kvm (Sẽ chạy chậm hơn)"; KVM_OPT=""; }
[ -e /dev/kvm ] && KVM_OPT="-enable-kvm -cpu host" || KVM_OPT="-cpu max"

### PREP ###
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Kiểm tra nếu chưa có ổ đĩa thì mới tạo
if [ ! -f "$DISK_FILE" ]; then
    echo "💾 Đang tạo ổ đĩa $DISK_SIZE..."
    qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"
fi

# Tải ISO nếu chưa có và chưa cài xong
if [ ! -f "$FLAG_FILE" ]; then
    if [ ! -f "$ISO_FILE" ]; then
        echo "🌐 Đang tải ISO Windows Server 2012 (Vui lòng đợi)..."
        wget --no-check-certificate -O "$ISO_FILE" "$ISO_URL"
    fi
fi

#################
# BORE START    #
#################
if [ ! -f "./bore" ]; then
    echo "📥 Đang cài đặt Bore Tunnel..."
    curl -L https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz | tar -xz
    chmod +x bore
fi

# Chạy Bore cho VNC (Port 5900)
nohup ./bore local $VNC_PORT --to bore.pub > bore_vnc.log 2>&1 &
sleep 5

VNC_PUBLIC=$(grep -oE 'bore.pub:[0-9]+' bore_vnc.log | head -n 1)

echo "------------------------------------------"
echo "🌍 VNC PUBLIC ADDRESS: $VNC_PUBLIC"
echo "👉 Dùng VNC Viewer kết nối vào địa chỉ trên để cài đặt."
echo "------------------------------------------"

#################
# RUN QEMU      #
#################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  CHẾ ĐỘ CÀI ĐẶT WINDOWS (LẦN ĐẦU)"
  echo "👉 Sau khi cài xong và đặt mật khẩu, hãy quay lại đây nhập: xong"

  ./qemu-system-x86_64 \
    $KVM_OPT \
    -smp "$CORES" \
    -m "$RAM" \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -net nic,model=virtio -net user \
    -vnc :0 \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Nhập 'xong' sau khi cài hoàn tất: " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID"
      pkill -f bore
      rm -f "$ISO_FILE"
      echo "✅ Hoàn tất! Lần sau chạy script sẽ boot thẳng vào Windows."
      exit 0
    fi
  done

else
  echo "✅ Windows đã cài – Đang khởi động..."
  
  ./qemu-system-x86_64 \
    $KVM_OPT \
    -smp "$CORES" \
    -m "$RAM" \
    -drive file="$DISK_FILE",if=virtio,format=qcow2 \
    -boot order=c \
    -net nic,model=virtio -net user \
    -vnc :0 \
    -usb -device usb-tablet \
    -nographic
fi
