import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

function includes(list, value) {
  return (list || []).includes(value);
}

export default class IpWatchlistQuickAdd extends Component {
  @service toasts;

  @tracked showModal = false;
  @tracked ipGroups = [];
  @tracked selectedIds = [];
  @tracked loading = false;
  @tracked memberOfGroups = [];
  @tracked subnetGroups = [];
  @tracked preloaded = false;

  static shouldRender(outletArgs) {
    return !!outletArgs?.model?.ip_address;
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
      const result = await ajax("/admin/ip-watchlist/ip-groups-for-ip", {
        data: { ip_address: this.ip },
      });
      this.applyStatus(result.ip_groups || []);
    } catch {
      // silently fail on preload
    }
  }

  applyStatus(groups) {
    this.ipGroups = groups;
    this.memberOfGroups = groups.filter((g) => g.is_member);
    this.subnetGroups = groups.filter((g) => !g.is_member && g.has_same_subnet);
    this.preloaded = true;
  }

  @action
  async openModal() {
    if (!this.ip) {
      return;
    }
    this.loading = true;
    this.showModal = true;
    try {
      const result = await ajax("/admin/ip-watchlist/ip-groups-for-ip", {
        data: { ip_address: this.ip },
      });
      const groups = result.ip_groups || [];
      this.applyStatus(groups);
      this.selectedIds = groups.filter((g) => g.is_member).map((g) => g.id);
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
      await ajax("/admin/ip-watchlist/quick-add-ip", {
        type: "POST",
        data: { ip_address: this.ip, ip_group_ids: newIds },
      });
      this.toasts.success({
        data: { message: i18n("admin.plugins.ip_watchlist.quick_add_success") },
        duration: "short",
      });
      this.showModal = false;
      await this.preloadStatus();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="ip-watchlist-quick-add">
      <div class="ip-watchlist-quick-add__label">
        {{i18n "admin.plugins.ip_watchlist.ip_group_status"}}
        <code>{{this.ip}}</code>
      </div>

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
              <span
                class="ip-watchlist-quick-add__badge --subnet"
                title={{i18n "admin.plugins.ip_watchlist.same_subnet_hint"}}
              >
                ⚠ {{g.name}}
              </span>
            {{/each}}
          </span>
        {{/if}}
        {{#unless this.memberOfGroups.length}}
          {{#unless this.subnetGroups.length}}
            <span class="ip-watchlist-quick-add__none">
              {{i18n "admin.plugins.ip_watchlist.not_in_any_ip_group"}}
            </span>
          {{/unless}}
        {{/unless}}
      {{/if}}

      <DButton
        class="btn-default btn-small"
        @icon="plus"
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
                      checked={{includes this.selectedIds g.id}}
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
