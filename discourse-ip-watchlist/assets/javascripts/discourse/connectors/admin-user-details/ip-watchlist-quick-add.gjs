import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class IpWatchlistQuickAdd extends Component {
  @service currentUser;
  @service toasts;
  @service modal;

  @tracked showModal = false;
  @tracked ipGroups = [];
  @tracked selectedIds = [];
  @tracked loading = false;
  @tracked memberOfGroups = [];
  @tracked subnetGroups = [];
  @tracked preloaded = false;

  static shouldRender(outletArgs) {
    return outletArgs?.model?.ip_address;
  }

  get ip() {
    return this.args.outletArgs?.model?.ip_address;
  }

  constructor() {
    super(...arguments);
    this.preloadStatus();
  }

  async preloadStatus() {
    if (!this.ip) {
      return;
    }
    try {
      const result = await ajax("/admin/plugins/ip-watchlist/ip-groups-for-ip", {
        data: { ip_address: this.ip },
      });
      const groups = result.ip_groups || [];
      this.memberOfGroups = groups.filter((g) => g.is_member);
      this.subnetGroups = groups.filter((g) => !g.is_member && g.has_same_subnet);
      this.preloaded = true;
    } catch {
      // silently fail on preload
    }
  }

  @action
  async openModal() {
    if (!this.ip) {
      return;
    }
    this.loading = true;
    this.showModal = true;
    try {
      const result = await ajax("/admin/plugins/ip-watchlist/ip-groups-for-ip", {
        data: { ip_address: this.ip },
      });
      this.ipGroups = result.ip_groups || [];
      this.selectedIds = this.ipGroups
        .filter((g) => g.is_member)
        .map((g) => g.id);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  closeModal() {
    this.showModal = false;
  }

  @action
  toggleGroup(groupId, event) {
    const id = Number(groupId);
    if (event?.target?.checked) {
      if (!this.selectedIds.includes(id)) {
        this.selectedIds = [...this.selectedIds, id];
      }
    } else {
      this.selectedIds = this.selectedIds.filter((g) => g !== id);
    }
  }

  @action
  async saveGroups() {
    const newIds = this.selectedIds.filter(
      (id) => !this.ipGroups.find((g) => g.id === id && g.is_member)
    );

    if (newIds.length === 0) {
      this.showModal = false;
      return;
    }

    try {
      await ajax("/admin/plugins/ip-watchlist/quick-add-ip", {
        type: "POST",
        data: { ip_address: this.ip, ip_group_ids: newIds },
      });
      this.toasts.success({
        data: { message: i18n("admin.plugins.ip_watchlist.quick_add_success") },
        duration: "short",
      });
      this.showModal = false;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="ip-watchlist-quick-add">
      {{#if this.preloaded}}
        {{#if this.memberOfGroups.length}}
          <span class="ip-watchlist-quick-add__badges">
            {{#each this.memberOfGroups as |g|}}
              <span class="ip-watchlist-quick-add__badge --member">{{g.name}}</span>
            {{/each}}
          </span>
        {{/if}}
        {{#if this.subnetGroups.length}}
          <span class="ip-watchlist-quick-add__badges">
            {{#each this.subnetGroups as |g|}}
              <span class="ip-watchlist-quick-add__badge --subnet" title="{{i18n "admin.plugins.ip_watchlist.same_subnet_hint"}}">
                ⚠ {{g.name}}
              </span>
            {{/each}}
          </span>
        {{/if}}
      {{/if}}
      <DButton
        class="btn-default btn-small"
        @icon="binoculars"
        @action={{this.openModal}}
        @translatedLabel={{i18n "admin.plugins.ip_watchlist.add_to_ip_group"}}
      />

      {{#if this.showModal}}
        <div class="ip-watchlist-quick-add__backdrop">
          <div class="ip-watchlist-quick-add__modal">
            <h3>{{i18n "admin.plugins.ip_watchlist.add_to_ip_group_title"}}</h3>
            <p><code>{{this.ip}}</code></p>

            {{#if this.loading}}
              <p>{{i18n "loading"}}</p>
            {{else if this.ipGroups.length}}
              <div class="ip-watchlist-quick-add__list">
                {{#each this.ipGroups as |g|}}
                  <label class="ip-watchlist-quick-add__option">
                    <input
                      type="checkbox"
                      checked={{g.is_member}}
                      disabled={{g.is_member}}
                      {{on "change" (fn this.toggleGroup g.id)}}
                    />
                    <strong>{{g.name}}</strong>
                    {{#if g.discourse_group_names.length}}
                      <span class="ip-watchlist-quick-add__linked">
                        → {{g.discourse_group_names}}
                      </span>
                    {{/if}}
                    {{#if g.is_member}}
                      <span class="ip-watchlist-quick-add__already">
                        ✓ {{i18n "admin.plugins.ip_watchlist.already_member"}}
                      </span>
                    {{else if g.has_same_subnet}}
                      <span class="ip-watchlist-quick-add__subnet-hint">
                        ⚠ {{i18n "admin.plugins.ip_watchlist.same_subnet_hint"}}:
                        {{#each g.same_subnet_ips as |sip|}}
                          <code>{{sip}}</code>
                        {{/each}}
                      </span>
                    {{/if}}
                  </label>
                {{/each}}
              </div>
            {{else}}
              <p>{{i18n "admin.plugins.ip_watchlist.no_ip_groups"}}</p>
            {{/if}}

            <div class="ip-watchlist-quick-add__actions">
              <DButton
                class="btn-default"
                @action={{this.closeModal}}
                @label="cancel"
              />
              {{#if this.ipGroups.length}}
                <DButton
                  class="btn-primary"
                  @action={{this.saveGroups}}
                  @translatedLabel={{i18n "admin.plugins.ip_watchlist.save"}}
                />
              {{/if}}
            </div>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
