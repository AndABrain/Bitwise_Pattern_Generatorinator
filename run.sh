#sudo apt install gcc-arm-linux-gnueabi
#sudo apt install qemu-user

arm-linux-gnueabi-as pattern.s -o pattern.o
arm-linux-gnueabi-ld pattern.o -o pattern
qemu-arm ./pattern