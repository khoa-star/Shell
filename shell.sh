#!/bin/bash

# --- Cấu hình 8 Core / 16GB RAM ---
RAM="16G"
CORES="8"
DISK="20G"
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
PORT=2222

echo "--- ĐANG KHỞI ĐỘNG HỆ THỐNG SHELL.SH ---"

# 1. Kiểm tra QEMU
if [ ! -f "./qemu-system-x86_64" ]; then
    echo "-> Đang tải QEMU..."
    curl -L https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static -o qemu-system-x86_64
    chmod +x qemu-system-x86_64
fi

# 2. Kiểm tra ISO (Nếu có rồi sẽ BỎ QUA không tải lại)
if [ ! -f "server2012.iso" ]; then
    echo "-> Đang tải ISO Windows Server 2012..."
    curl -L "$ISO_URL" -o server2012.iso
else
    echo "-> Đã tìm thấy ISO, bỏ qua bước tải."
fi

# 3. Kiểm tra Ổ đĩa ảo (Nếu có rồi sẽ GIỮ LẠI dữ liệu cũ)
if [ ! -f "ws2012.qcow2" ]; then
    echo "-> Đang tạo ổ đĩa 20GB..."
    qemu-img create -f qcow2 ws2012.qcow2 $DISK
else
    echo "-> Đã có ổ đĩa, đang khởi động từ dữ liệu cũ."
fi

# 4. Chạy QEMU ngầm
./qemu-system-x86_64 \
  -m $RAM -smp $CORES -cpu max \
  -drive file=ws2012.qcow2,format=qcow2 -cdrom server2012.iso \
  -vnc :1 -net nic,model=e1000 -net user,hostfwd=tcp:127.0.0.1:$PORT-:22 \
  -nographic > /dev/null 2>&1 &

# 5. Tự động đợi và SSH (Giống Proot)
echo "--- Đang chờ Windows Shell sẵn sàng (Port $PORT) ---"
while ! timeout 1 bash -c "cat < /dev/tcp/127.0.0.1/$PORT" >/dev/null 2>&1; do
  printf "."
  sleep 10
done

echo -e "\n--- ĐÃ KẾT NỐI VÀO WINDOWS SHELL ---"
ssh -p $PORT -o StrictHostKeyChecking=no Administrator@127.0.0.1
