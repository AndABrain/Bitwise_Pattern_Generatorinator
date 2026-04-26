# sudo apt install gcc-aarch64-linux-gnu
# sudo apt install qemu-user
# sudo apt install libc6-arm64-cross

aarch64-linux-gnu-gcc -static -o timer timer.s
/home/ubuntu/.jdks/openjdk-26.0.1/bin/java -javaagent:/opt/intellij/lib/idea_rt.jar=41693 -Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8 -classpath /home/ubuntu/.m2/repository/org/openjfx/javafx-controls/21.0.6/javafx-controls-21.0.6.jar:/home/ubuntu/.m2/repository/org/openjfx/javafx-graphics/21.0.6/javafx-graphics-21.0.6.jar:/home/ubuntu/.m2/repository/org/openjfx/javafx-base/21.0.6/javafx-base-21.0.6.jar:/home/ubuntu/.m2/repository/org/openjfx/javafx-fxml/21.0.6/javafx-fxml-21.0.6.jar -p /home/ubuntu/.m2/repository/org/openjfx/javafx-base/21.0.6/javafx-base-21.0.6-linux.jar:/home/ubuntu/Documents/pattern/gridPane/target/classes:/home/ubuntu/.m2/repository/org/openjfx/javafx-graphics/21.0.6/javafx-graphics-21.0.6-linux.jar:/home/ubuntu/.m2/repository/org/openjfx/javafx-fxml/21.0.6/javafx-fxml-21.0.6-linux.jar:/home/ubuntu/.m2/repository/org/openjfx/javafx-controls/21.0.6/javafx-controls-21.0.6-linux.jar -m gridgui.gridpane/gridgui.gridpane.GridApplication 2> /dev/null &
processID=$! 
trap "kill $processID" EXIT
qemu-aarch64 ./timer