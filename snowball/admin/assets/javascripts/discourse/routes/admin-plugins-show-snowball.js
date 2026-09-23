import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowSnowballRoute extends DiscourseRoute {
  @service currentUser;

  async model() {
    if (!this.currentUser?.admin) {
      return null;
    }

    return await ajax("/admin/snowball/seeds");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.stats = model;
  }
}
