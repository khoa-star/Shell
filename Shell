#!/bin/bash

# Cấu hình hệ thống theo yêu cầu
RAM="16G"
CORES="8"
DISK="20G"
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"

# 1. Tải QEMU Static (Chạy không cần root)
if [ ! -f "qemu-system-x86_64" ]; then
    echo "--- Đang tải bộ giả lập QEMU ---"
    curl -L https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static -o qemu-system-x86_64
    chmod +x qemu-system-x86_64
fi

# 2. Tạo ổ cứng ảo 20GB
if [ ! -f "ws2012.qcow2" ]; then
    echo "--- Khởi tạo ổ đĩa 20GB ---"
    qemu-img create -f qcow2 ws2012.qcow2 20G
fi

# 3. Tải ISO Windows Server 2012
if [ ! -f "server2012.iso" ]; then
    echo "--- Đang tải ISO Windows Server 2012... ---"
    curl -L "$ISO_URL" -o server2012.iso
fi

# 4. Chạy QEMU dưới nền (Background)
# hostfwd=tcp:127.0.0.1:2222-:22 => Đẩy cổng SSH vào trong VM
echo "--- Đang khởi động Windows Server 2012 (8 Core / 16GB RAM) ---"
./qemu-system-x86_64 \
  -m $RAM \
  -smp $CORES \
  -cpu host,migratable=on \
  -drive file=ws2012.qcow2,format=qcow2 \
  -cdrom server2012.iso \
  -vnc :1 \
  -net nic,model=e1000 -net user,hostfwd=tcp:127.0.0.1:2222-:22 \
  -nographic > /dev/null 2>&1 &

# 5. Vòng lặp chờ đợi để tự động SSH (Cơ chế giống Proot)
echo "--- Đang chờ Windows Server mở cổng SSH (localhost:2222)... ---"
echo "Lưu ý: Lần đầu bạn phải dùng VNC (Port 5901) để cài đặt và bật SSH Server."

while ! nc -z localhost 2222; do
  printf "."
  sleep 10
done

echo -e "\n--- KẾT NỐI THÀNH CÔNG! ---"
ssh -p 2222 -o StrictHostKeyChecking=no Administrator@127.0.0.1
