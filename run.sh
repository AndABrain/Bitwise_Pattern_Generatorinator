aarch64-linux-gnu-gcc -static -o timer timer.s
command="<COPY_HERE>"
$command 2> /dev/null &
processID=$! 
trap "kill $processID" EXIT
qemu-aarch64 ./timer
