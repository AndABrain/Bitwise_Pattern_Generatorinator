# sudo apt install gcc-aarch64-linux-gnu
# sudo apt install qemu-user
# sudo apt install libc6-arm64-cross

aarch64-linux-gnu-gcc -static -o timer timer.s
# truncate -s 0 output.bin
qemu-aarch64 ./timer
# qemu-aarch64 ./timer > output.bin
# xxd -b -c 6 output.bin