import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "snowball-admin-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("discourse-snowball", [
        {
          label: "admin.plugins.snowball.title",
          route: "adminPlugins.show.snowball",
        },
      ]);
    });
  },
};
