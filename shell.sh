#!/bin/bash

# --- Cấu hình hệ thống (8 Core / 16GB RAM) ---
RAM="16G"
CORES="8"
DISK="20G"
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
PORT=2222

echo "--- BẮT ĐẦU QUY TRÌNH TỰ ĐỘNG HÓA WINDOWS SERVER 2012 ---"

# 0. Dọn dẹp các tiến trình cũ để giải phóng RAM
echo "-> Đang dọn dẹp tiến trình cũ..."
pkill -f qemu-system-x86_64
pkill -f bore
rm -f bore_info

# 1. Tải QEMU System (Bản tĩnh - No Root)
if [ ! -f "./qemu-system-x86_64" ]; then
    echo "-> Đang tải QEMU System..."
    curl -L https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static -o qemu-system-x86_64
    chmod +x qemu-system-x86_64
else
    echo "-> Đã có QEMU System, bỏ qua."
fi

# 2. Tải QEMU Img (Sửa lỗi command not found)
if [ ! -f "./qemu-img" ]; then
    echo "-> Đang tải công cụ tạo đĩa qemu-img..."
    curl -L https://github.com/minos-org/minos-static/raw/master/bin/qemu-img -o qemu-img
    chmod +x qemu-img
else
    echo "-> Đã có qemu-img, bỏ qua."
fi

# 3. Kiểm tra và tải ISO Windows Server 2012
if [ ! -f "server2012.iso" ]; then
    echo "-> Đang tải ISO (5GB) - Vui lòng đợi..."
    curl -L "$ISO_URL" -o server2012.iso
else
    echo "-> Đã tìm thấy ISO, bỏ qua bước tải."
fi

# 4. Kiểm tra và tạo ổ đĩa ảo
if [ ! -f "ws2012.qcow2" ]; then
    echo "-> Đang khởi tạo ổ đĩa $DISK..."
    ./qemu-img create -f qcow2 ws2012.qcow2 $DISK
else
    echo "-> Đã có ổ đĩa ws2012.qcow2, giữ nguyên dữ liệu cũ."
fi

# 5. Tải Bore Tunnel để kết nối từ xa
if [ ! -f "bore" ]; then
    echo "-> Đang cài đặt Bore Tunnel..."
    curl -L https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz | tar -xz
    chmod +x bore
fi

# 6. Khởi chạy QEMU ngầm (Background)
echo "--- ĐANG KHỞI ĐỘNG MÁY ẢO (8 CORES / 16GB RAM) ---"
./qemu-system-x86_64 \
  -m $RAM -smp $CORES -cpu max \
  -drive file=ws2012.qcow2,format=qcow2 -cdrom server2012.iso \
  -vnc :1 -net nic,model=e1000 -net user,hostfwd=tcp:127.0.0.1:$PORT-:22 \
  -nographic > /dev/null 2>&1 &

# 7. Mở Tunnel ra Internet và lưu thông tin vào file
nohup ./bore local $PORT --to bore.pub > bore_info 2>&1 &
sleep 5
echo "--- THÔNG TIN KẾT NỐI TỪ XA ---"
cat bore_info | grep "listening at" || echo "Đang khởi tạo tunnel..."

# 8. Tự động đợi để nhảy vào Windows Shell (Giống Proot)
echo "--- Đang đợi Windows bật SSH (localhost:$PORT)... ---"
while ! timeout 1 bash -c "cat < /dev/tcp/127.0.0.1/$PORT" >/dev/null 2>&1; do
  printf "."
  sleep 10
done

echo -e "\n--- ĐÃ KẾT NỐI THÀNH CÔNG VÀO WINDOWS SHELL ---"
ssh -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null Administrator@127.0.0.1
