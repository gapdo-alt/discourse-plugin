import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "snowball-nav",
  initialize() {
    withPluginApi("1.8.0", (api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (!siteSettings.snowball_enabled || !siteSettings.snowball_show_nav_link) {
        return;
      }

      api.addCommunitySectionLink((dropdown) => {
        dropdown.addLink({
          name: "snowball-verify",
          route: "snowballVerify",
          title: i18n("snowball.nav_title"),
          label: i18n("snowball.nav_title"),
          icon: "id-card",
        });
      });
    });
  },
};
