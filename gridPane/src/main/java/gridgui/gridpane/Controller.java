package gridgui.gridpane;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.ResourceBundle;

import javafx.application.Platform;
import javafx.fxml.FXML;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.paint.Color;

public class Controller {

    @FXML
    private ResourceBundle resources;

    @FXML
    private Canvas canvas;

    @FXML
    private URL location;
    private static Path frameBufferPath;
    private byte[] currentBytes;
    private GraphicsContext canvasGC;

    private final static int colNums = 6;
    private final static int rowNums = 48;
    private final static int numBytes = 288;
    private final static int cellSize = 10;

    @FXML
    void initialize() {
        currentBytes = new byte[numBytes];
        canvasGC = canvas.getGraphicsContext2D();
        try{
            Path currentDir = Paths.get("").toAbsolutePath();
            if(currentDir.toString().equals("/home/ubuntu/Documents/pattern/gridPane")){
                currentDir = currentDir.getParent();
            }
            frameBufferPath = Paths.get(currentDir + "/frameBuffer.bin");
            // Test that this file path lets us read the frameBuffer file
            if (frameBufferPath==null || !Files.exists(frameBufferPath) || !Files.isReadable(frameBufferPath)) throw new Exception();
        }catch (Exception e){
            System.out.println("Can't get frameBuffer file");
            System.exit(1);
        }
        Thread writeThread = new Thread(() -> {
            while(true){
                try{
                   if(readFile()){
                       Platform.runLater(() -> {
                           updateGUI();
                       });
                   }
                   Thread.sleep(10);
                }catch(InterruptedException e){
                    break;
                }
            }
        });
        writeThread.setDaemon(true);
        writeThread.start();
    }

    public boolean readFile() {
        try{
            byte[] bytes = Files.readAllBytes(frameBufferPath);
            if(bytes.length == numBytes && !Arrays.equals(bytes, currentBytes)){
                currentBytes = bytes;
                return true;
            }
            return false;
        }catch(IOException ignored) {
            return false;
        }
    }

    public void fillBlack(int row, int col, int bitOffset){
        canvasGC.setFill(Color.GRAY);
        canvasGC.fillRect((bitOffset +col*8)*cellSize, row*cellSize, cellSize, cellSize);
    }

    public void fillWhite(int row, int col, int bitOffset){
        canvasGC.setFill(Color.CYAN);
        canvasGC.fillRect((bitOffset +col*8)*cellSize, row*cellSize, cellSize, cellSize);
    }

    public void updateGUI(){
        for(int row = 0; row < rowNums; row++){
            for(int col = 0; col < colNums; col++){
                byte currentByte = currentBytes[(row*colNums)+col];
                for(int bitNum = 8; bitNum >= 1; bitNum--){
                    int bit = (currentByte >> (bitNum-1)) & 1;
                    if(bit==1){
                        fillWhite(row, col, 8 - bitNum);
                    }else{
                        fillBlack(row, col, 8 - bitNum);
                    }
                }
            }
        }
    }
}
