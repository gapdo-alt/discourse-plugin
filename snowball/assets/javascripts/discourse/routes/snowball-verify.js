import Route from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class SnowballVerifyRoute extends Route {
  titleToken() {
    return i18n("snowball.verify_title");
  }

  beforeModel() {
    if (!this.currentUser) {
      this.session.requireAuthentication(this);
    }
  }
}
