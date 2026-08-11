import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "ip-watchlist-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("discourse-ip-watchlist", [
        {
          label: "admin.plugins.ip_watchlist.title",
          route: "adminPlugins.show.ip-watchlist",
        },
      ]);
    });
  },
};
