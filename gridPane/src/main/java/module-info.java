module gridgui.gridpane {
    requires javafx.controls;
    requires javafx.fxml;


    opens gridgui.gridpane to javafx.fxml;
    exports gridgui.gridpane;
}