package com.example.views;

import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.Route;
import com.vaadin.modernization.swing.bridge.component.SwingBridge;

@Route(value = "chess")
public class ChessGameView extends VerticalLayout {
    private static final String MAIN_CLASS = "com.ChessGame";

    public ChessGameView() {
        add(new SwingBridge(MAIN_CLASS));
        setSizeFull();
    }

}
