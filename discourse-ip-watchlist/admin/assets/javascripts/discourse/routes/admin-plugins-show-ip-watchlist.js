import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowIpWatchlistRoute extends DiscourseRoute {
  @service currentUser;

  async model(params) {
    if (!this.currentUser?.admin) {
      return { entries: [], enforcements: [], groups: [] };
    }

    const q = params?.q;
    const url = q
      ? `/admin/plugins/ip-watchlist?q=${encodeURIComponent(q)}`
      : "/admin/plugins/ip-watchlist";

    return await ajax(url);
  }
}
