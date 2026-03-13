package com.herberts.views.badges;

import com.vaadin.flow.component.DetachEvent;
import com.vaadin.flow.component.badge.Badge;
import com.vaadin.flow.component.badge.BadgeVariant;
import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.Image;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.html.Span;
import com.vaadin.flow.component.icon.VaadinIcon;
import com.vaadin.flow.component.orderedlayout.HorizontalLayout;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.component.textfield.TextField;
import com.vaadin.flow.router.Menu;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.signals.impl.Effect;
import com.vaadin.flow.signals.local.ValueSignal;
import com.vaadin.flow.signals.shared.SharedValueSignal;
import com.vaadin.flow.theme.lumo.LumoUtility.Margin;
import jakarta.annotation.security.PermitAll;
import org.vaadin.lineawesome.LineAwesomeIconUrl;

@PageTitle("Badges")
@Route("")
@Menu(order = 0, icon = LineAwesomeIconUrl.FILE)
@PermitAll
public class BadgesView extends VerticalLayout {

    private ValueSignal<Integer> timerSignal;
    private SharedValueSignal<String> timer2Signal;
    private Thread thread;

    protected Badge badge2;

    TextField name;
    Button sayHello;

    public BadgesView() {
        timerSignal = new ValueSignal<>(0);
        timer2Signal = new SharedValueSignal<>("0");

        thread = new Thread(() -> {
            for (int i = 0; i < 1000; i++) {
                timerSignal.update(time -> {
                    System.out.println("Updating badge value to " + (time + 1));
                    return time + 1;
                });
                timer2Signal.update(time -> {
                    System.out.println("Updating text badge value to " + (Integer.parseInt(time) + 1));
                    return String.valueOf(Integer.parseInt(time) + 1);
                });
				try {
					Thread.sleep(1000);
				} catch (InterruptedException e) {
					System.out.println("Thread interrupted at " + timerSignal.peek());
				}
			}
        });
        thread.start();

        var badge1 = new Badge();
        badge2 = new Badge("2");
        badge2.addThemeVariants(BadgeVariant.ERROR);
        var badge3 = new Badge(VaadinIcon.BELL_O.create());
        badge3.addThemeVariants(BadgeVariant.SUCCESS);
        var badge4 = new Badge("Alerts", VaadinIcon.BELL_O.create());
        badge4.setId("badge4");
        var badge5 = new Badge(VaadinIcon.TIMER.create());
        badge5.bindNumber(timerSignal);
        badge5.addThemeVariants(BadgeVariant.CONTRAST);
        var span = new Span();
        span.bindText(timer2Signal);

        add(new HorizontalLayout(badge1, badge2, badge3, badge4, badge5, span));
    }

    @Override
    protected void onDetach(DetachEvent detachEvent) {
        super.onDetach(detachEvent);
        thread.interrupt();
    }
}
