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

      // addCommunitySectionLink accepts a plain descriptor object (the same
      // shape core's discourse-cakeday uses) or a factory that returns a
      // subclass of the base section link.  The descriptor is read through
      // name/text/title/href/route/icon getters, so `label` is not a valid
      // key -- the visible text must be passed as `text`.
      api.addCommunitySectionLink({
        name: "snowball-verify",
        route: "snowballVerify",
        title: i18n("snowball.nav_title"),
        text: i18n("snowball.nav_title"),
        icon: "id-card",
      });
    });
  },
};
