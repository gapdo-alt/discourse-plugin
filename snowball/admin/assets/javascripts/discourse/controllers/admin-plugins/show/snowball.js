import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const PER_PAGE = 50;
const BASE = "admin.plugins.snowball";

// Column definitions for the three library readers.  Keeping them as data
// means the template can render any of the tables without a branch per kind.
const COLUMNS = {
  seeds: [
    { key: "employee_id", label: `${BASE}.col_employee_id`, format: "id" },
    { key: "surname", label: `${BASE}.col_surname` },
    { key: "confidence", label: `${BASE}.col_confidence` },
    { key: "status", label: `${BASE}.col_status` },
    { key: "in_active_pool", label: `${BASE}.col_in_pool`, format: "bool" },
    { key: "resigned_signals", label: `${BASE}.col_resigned_signals` },
    { key: "updated_at", label: `${BASE}.col_updated_at`, format: "time" },
  ],
  observations: [
    { key: "employee_id", label: `${BASE}.col_employee_id`, format: "id" },
    { key: "votes_text", label: `${BASE}.col_votes` },
    { key: "total", label: `${BASE}.col_total` },
    { key: "updated_at", label: `${BASE}.col_updated_at`, format: "time" },
  ],
  resigned_observations: [
    { key: "employee_id", label: `${BASE}.col_employee_id`, format: "id" },
    { key: "resigned_votes", label: `${BASE}.col_resigned_votes` },
    { key: "probe_weight", label: `${BASE}.col_probe_weight`, format: "weight" },
    { key: "range_radius", label: `${BASE}.col_range_radius` },
    { key: "updated_at", label: `${BASE}.col_updated_at`, format: "time" },
  ],
  // One row per submitted verification (pass or fail), so an admin can see who
  // tried, when, and what the account's current verification state is.
  verifications: [
    { key: "created_at", label: `${BASE}.col_attempted_at`, format: "time" },
    { key: "username", label: `${BASE}.col_username` },
    { key: "outcome", label: `${BASE}.col_outcome`, format: "outcome" },
    { key: "verified_at", label: `${BASE}.col_verified_at`, format: "time" },
    { key: "expires_at", label: `${BASE}.col_expires_at`, format: "time" },
  ],
};

export default class AdminPluginsShowSnowballController extends Controller {
  @service dialog;
  @service toasts;

  @tracked stats = null;
  @tracked importing = false;
  @tracked lastResult = "";

  // Library viewer: null while closed, otherwise one of the COLUMNS keys.
  @tracked libraryKind = null;
  @tracked library = null;
  @tracked libraryPage = 1;
  @tracked libraryQuery = "";
  @tracked libraryLoading = false;

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

  get statVerifiedUsers() {
    return this.stats?.verified_users ?? "—";
  }

  get statVerifications() {
    return this.stats?.verifications ?? "—";
  }

  get libraryOpen() {
    return this.libraryKind !== null;
  }

  get libraryTitle() {
    return this.libraryKind ? i18n(`${BASE}.library_${this.libraryKind}`) : "";
  }

  get librarySearchPlaceholder() {
    return i18n(
      this.libraryKind === "verifications"
        ? `${BASE}.library_search_username`
        : `${BASE}.library_search_placeholder`
    );
  }

  get libraryColumns() {
    return COLUMNS[this.libraryKind] ?? [];
  }

  get libraryRows() {
    const items = this.library?.items ?? [];

    if (this.libraryKind === "observations") {
      return items.map((row) => ({
        ...row,
        votes_text: Object.entries(row.votes || {})
          .map(([surname, count]) => `${surname}×${count}`)
          .join("、"),
      }));
    }

    return items;
  }

  get libraryTotal() {
    return this.library?.total ?? 0;
  }

  get libraryPages() {
    return Math.max(1, Math.ceil(this.libraryTotal / (this.library?.per_page || PER_PAGE)));
  }

  @action
  async refresh() {
    try {
      this.stats = await ajax("/admin/snowball/seeds");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  // Clicking the active library button again closes the panel.
  @action
  async openLibrary(kind) {
    if (this.libraryKind === kind) {
      this.closeLibrary();
      return;
    }

    this.libraryKind = kind;
    this.libraryPage = 1;
    this.libraryQuery = "";
    this.library = null;
    await this._loadLibrary();
  }

  @action
  closeLibrary() {
    this.libraryKind = null;
    this.library = null;
    this.libraryPage = 1;
    this.libraryQuery = "";
  }

  @action
  async loadLibraryPage(delta) {
    const next = this.libraryPage + delta;
    if (next < 1 || next > this.libraryPages) {
      return;
    }

    this.libraryPage = next;
    await this._loadLibrary();
  }

  @action
  onLibraryQuery(event) {
    this.libraryQuery = event.target.value;
  }

  @action
  onLibraryQueryKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.searchLibrary();
    }
  }

  @action
  async searchLibrary() {
    this.libraryPage = 1;
    await this._loadLibrary();
  }

  async _loadLibrary() {
    if (!this.libraryKind) {
      return;
    }

    this.libraryLoading = true;

    try {
      this.library = await ajax(`/admin/snowball/library/${this.libraryKind}`, {
        data: { page: this.libraryPage, per_page: PER_PAGE, q: this.libraryQuery || undefined },
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.libraryLoading = false;
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

      // Keep an open list in sync with the freshly imported rows.
      if (this.libraryOpen) {
        await this._loadLibrary();
      }
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
          if (this.libraryOpen) {
            await this._loadLibrary();
          }
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }
}
