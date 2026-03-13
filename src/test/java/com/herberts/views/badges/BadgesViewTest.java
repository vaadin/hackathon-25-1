package com.herberts.views.badges;

import com.herberts.views.login.LoginView;
import com.vaadin.browserless.SpringBrowserlessTest;
import com.vaadin.flow.component.badge.Badge;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.test.context.support.WithMockUser;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest
public class BadgesViewTest extends SpringBrowserlessTest {
	@Test
	@WithMockUser(username = "user", roles = "USER")
	public void setBadgeText() {

		final BadgesView view = navigate(BadgesView.class);
		test(view.badge2).getComponent().setText("testext");
		assertEquals("testext", test(view.badge2).getComponent().getText());
	}

	@Test
	@WithMockUser(username = "user", roles = "USER")
	public void verifyBadge4Text() {

		final BadgesView view = navigate(BadgesView.class);
		var badge = $(Badge.class).id("badge4");
		assertNotNull(badge);
		assertEquals("Alerts", badge.getText());
	}
}
