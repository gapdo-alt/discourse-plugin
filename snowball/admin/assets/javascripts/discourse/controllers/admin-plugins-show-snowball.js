import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowSnowballController extends Controller {
  @service dialog;
  @service toasts;

  @tracked stats = null;
  @tracked importing = false;
  @tracked lastResult = "";

  get statSeeds() {
    return this.stats?.seeds ?? "—";
  }

  get statUsable() {
    return this.stats?.usable_seeds ?? "—";
  }

  get statObservations() {
    return this.stats?.observations ?? "—";
  }

  get statResigned() {
    return this.stats?.resigned_observations ?? "—";
  }

  get statUpdated() {
    return this.stats?.last_seed_at ? this.stats.last_seed_at.slice(0, 19).replace("T", " ") : "—";
  }

  @action
  async refresh() {
    try {
      this.stats = await ajax("/admin/snowball/seeds");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  // Reads the picked .json file and posts its content as the `payload` param.
  @action
  async onFileSelected(event) {
    const file = event.target?.files?.[0];
    if (!file) {
      return;
    }

    this.importing = true;
    this.lastResult = "";

    try {
      const payload = await file.text();
      const result = await ajax("/admin/snowball/seeds", {
        type: "POST",
        data: { payload },
      });

      this.stats = result.stats;
      this.lastResult = i18n("admin.plugins.snowball.import_ok", {
        seeds: result.imported.seeds,
        observations: result.imported.observations,
        resigned: result.imported.resigned_observations,
      });
      this.toasts.success({ data: { message: this.lastResult }, duration: "short" });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.importing = false;
      event.target.value = "";
    }
  }

  @action
  wipe() {
    this.dialog.deleteConfirm({
      message: i18n("admin.plugins.snowball.wipe_confirm"),
      didConfirm: async () => {
        try {
          const result = await ajax("/admin/snowball/seeds", { type: "DELETE" });
          this.stats = result.stats;
          this.lastResult = "";
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }
}
