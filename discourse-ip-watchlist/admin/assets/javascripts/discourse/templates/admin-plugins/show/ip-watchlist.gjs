import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

function eq(a, b) {
  return a === b;
}

function includes(list, value) {
  return (list || []).includes(value);
}

export default RouteTemplate(
  <template>
    <div class="ip-watchlist-admin admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "admin.plugins.ip_watchlist.title"}}
        @descriptionLabel={{i18n "admin.plugins.ip_watchlist.description"}}
      />

      <p class="ip-watchlist-admin__settings-link">
        <a href="/admin/site_settings/category/plugins?filter=ip_watchlist">
          {{i18n "admin.plugins.ip_watchlist.settings_link"}}
        </a>
      </p>

      <div class="ip-watchlist-admin__tabs">
        <DButton
          class={{if (eq @controller.activeTab "watchlist") "btn-primary" "btn-default"}}
          @action={{fn @controller.switchTab "watchlist"}}
          @translatedLabel={{i18n "admin.plugins.ip_watchlist.watchlist_tab"}}
        />
        <DButton
          class={{if (eq @controller.activeTab "enforcement") "btn-primary" "btn-default"}}
          @action={{fn @controller.switchTab "enforcement"}}
          @translatedLabel={{i18n "admin.plugins.ip_watchlist.enforcement_tab"}}
        />
        <DButton
          class={{if (eq @controller.activeTab "ip_groups") "btn-primary" "btn-default"}}
          @action={{@controller.switchToIpGroups}}
          @translatedLabel={{i18n "admin.plugins.ip_watchlist.ip_groups_tab"}}
        />
      </div>

      {{#if (eq @controller.activeTab "watchlist")}}
        <div class="ip-watchlist-admin__toolbar">
          <input
            type="search"
            value={{@controller.search}}
            {{on "input" @controller.updateSearch}}
            placeholder={{i18n "admin.plugins.ip_watchlist.search_placeholder"}}
            class="ip-watchlist-admin__search"
          />
          <DButton
            class="btn-default"
            @action={{@controller.searchWatchlist}}
            @icon="magnifying-glass"
          />
          <input
            type="text"
            value={{@controller.newIp}}
            {{on "input" @controller.updateNewIp}}
            placeholder={{i18n "admin.plugins.ip_watchlist.add_ip_placeholder"}}
            class="ip-watchlist-admin__add-ip"
          />
          <DButton
            class="btn-primary"
            @action={{@controller.addIp}}
            @translatedLabel={{i18n "admin.plugins.ip_watchlist.add_ip"}}
          />
        </div>

        {{#if @controller.model.entries.length}}
          <table class="ip-watchlist-admin__table">
            <thead>
              <tr>
                <th>{{i18n "admin.plugins.ip_watchlist.ip"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.reason"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.organization"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.hostname"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.hits"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.related_users"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.last_seen"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @controller.model.entries as |entry|}}
                <tr>
                  <td><code>{{entry.ip_address}}</code></td>
                  <td>
                    {{i18n (concat "admin.plugins.ip_watchlist.reasons." entry.reason)}}
                  </td>
                  <td>{{entry.organization}}</td>
                  <td>{{entry.hostname}}</td>
                  <td>{{entry.hit_count}}</td>
                  <td>
                    <a href={{entry.same_ip_admin_url}}>
                      {{entry.related_user_count}}
                      ·
                      {{i18n "admin.plugins.ip_watchlist.same_ip_users"}}
                    </a>
                  </td>
                  <td>{{entry.last_seen_at}}</td>
                  <td class="ip-watchlist-admin__actions">
                    <DButton
                      class="btn-small btn-primary"
                      @action={{fn @controller.openPromote entry}}
                      @translatedLabel={{i18n "admin.plugins.ip_watchlist.promote"}}
                    />
                    <DButton
                      class="btn-small btn-danger"
                      @icon="trash-can"
                      @action={{fn @controller.deleteEntry entry}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p class="ip-watchlist-admin__empty">
            {{i18n "admin.plugins.ip_watchlist.empty_watchlist"}}
          </p>
        {{/if}}
      {{/if}}

      {{#if (eq @controller.activeTab "enforcement")}}
        <div class="ip-watchlist-admin__toolbar">
          <input
            type="text"
            value={{@controller.newEnforcementIp}}
            {{on "input" @controller.updateNewEnforcementIp}}
            placeholder={{i18n "admin.plugins.ip_watchlist.add_ip_placeholder"}}
            class="ip-watchlist-admin__add-ip"
          />
          <select
            {{on "change" @controller.updateNewEnforcementGroupId}}
            class="ip-watchlist-admin__group-select"
          >
            <option value="">{{i18n "admin.plugins.ip_watchlist.group"}}</option>
            {{#each @controller.model.groups as |group|}}
              <option value={{group.id}}>{{group.name}}</option>
            {{/each}}
          </select>
          <DButton
            class="btn-primary"
            @action={{@controller.createEnforcement}}
            @translatedLabel={{i18n "admin.plugins.ip_watchlist.create_enforcement"}}
          />
        </div>

        {{#if @controller.model.enforcements.length}}
          <table class="ip-watchlist-admin__table">
            <thead>
              <tr>
                <th>{{i18n "admin.plugins.ip_watchlist.ip"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.group"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.enabled"}}</th>
                <th>{{i18n "admin.plugins.ip_watchlist.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @controller.model.enforcements as |row|}}
                <tr>
                  <td><code>{{row.ip_address}}</code></td>
                  <td>{{row.group_name}}</td>
                  <td>{{if row.enabled "✓" "—"}}</td>
                  <td class="ip-watchlist-admin__actions">
                    <DButton
                      class="btn-small btn-default"
                      @action={{fn @controller.toggleEnforcement row}}
                      @translatedLabel={{if
                        row.enabled
                        (i18n "admin.plugins.ip_watchlist.disable")
                        (i18n "admin.plugins.ip_watchlist.enable")
                      }}
                    />
                    <DButton
                      class="btn-small btn-danger"
                      @icon="trash-can"
                      @action={{fn @controller.deleteEnforcement row}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <p class="ip-watchlist-admin__empty">
            {{i18n "admin.plugins.ip_watchlist.empty_enforcements"}}
          </p>
        {{/if}}
      {{/if}}

      {{#if (eq @controller.activeTab "ip_groups")}}
        {{#if @controller.ipGroupsData}}
          <div class="ip-watchlist-admin__toolbar">
            <input
              type="text"
              value={{@controller.newIpGroupName}}
              {{on "input" @controller.updateNewIpGroupName}}
              placeholder={{i18n "admin.plugins.ip_watchlist.ip_group_name_placeholder"}}
              class="ip-watchlist-admin__add-ip"
            />
            <DButton
              class="btn-primary"
              @action={{@controller.createIpGroup}}
              @translatedLabel={{i18n "admin.plugins.ip_watchlist.create_ip_group"}}
            />
          </div>
          {{#if @controller.ipGroupsData.discourse_groups.length}}
            <div class="ip-watchlist-admin__group-list" style="margin-bottom: 1rem;">
              <p>{{i18n "admin.plugins.ip_watchlist.linked_groups"}}（创建时可选）:</p>
              {{#each @controller.ipGroupsData.discourse_groups as |dg|}}
                <label class="ip-watchlist-admin__group-option">
                  <input
                    type="checkbox"
                    checked={{includes @controller.newIpGroupDiscourseGroupIds dg.id}}
                    {{on "change" (fn @controller.toggleNewIpGroupDiscourseGroup dg.id)}}
                  />
                  {{dg.name}}
                </label>
              {{/each}}
            </div>
          {{/if}}

          {{#if @controller.ipGroupsData.ip_groups.length}}
            {{#each @controller.ipGroupsData.ip_groups as |ipGroup|}}
              <div class="ip-watchlist-admin__ip-group-card">
                <div class="ip-watchlist-admin__ip-group-header">
                  <h4>{{ipGroup.name}}</h4>
                  <div class="ip-watchlist-admin__actions">
                    <DButton
                      class="btn-small btn-default"
                      @action={{fn @controller.startEditIpGroup ipGroup}}
                      @icon="pencil"
                    />
                    <DButton
                      class="btn-small btn-danger"
                      @icon="trash-can"
                      @action={{fn @controller.deleteIpGroup ipGroup}}
                    />
                  </div>
                </div>
                <p>
                  {{i18n "admin.plugins.ip_watchlist.linked_groups"}}:
                  {{#if ipGroup.discourse_group_names.length}}
                    {{ipGroup.discourse_group_names}}
                  {{else}}
                    —
                  {{/if}}
                </p>
                <p>
                  {{i18n "admin.plugins.ip_watchlist.members"}}
                  ({{ipGroup.membership_count}}):
                </p>
                <div class="ip-watchlist-admin__ip-tags">
                  {{#each ipGroup.member_ips as |ip|}}
                    <span class="ip-watchlist-admin__ip-tag">
                      {{ip}}
                      <DButton
                        class="btn-flat btn-small"
                        @icon="xmark"
                        @action={{fn @controller.removeIpFromGroup ipGroup ip}}
                      />
                    </span>
                  {{/each}}
                </div>
                <div class="ip-watchlist-admin__toolbar" style="margin-top: 0.5rem;">
                  <input
                    type="text"
                    value={{get @controller.addIpByGroupId ipGroup.id}}
                    {{on "input" (fn @controller.updateAddIpForGroup ipGroup.id)}}
                    placeholder={{i18n "admin.plugins.ip_watchlist.add_ip_placeholder"}}
                    class="ip-watchlist-admin__add-ip"
                  />
                  <DButton
                    class="btn-small btn-primary"
                    @action={{fn @controller.addIpToGroup ipGroup}}
                    @translatedLabel={{i18n "admin.plugins.ip_watchlist.add_ip_to_group"}}
                  />
                </div>
              </div>
            {{/each}}
          {{else}}
            <p class="ip-watchlist-admin__empty">
              {{i18n "admin.plugins.ip_watchlist.empty_ip_groups"}}
            </p>
          {{/if}}
        {{else}}
          <p>{{i18n "loading"}}</p>
        {{/if}}
      {{/if}}

      {{#if @controller.editingIpGroup}}
        <div class="ip-watchlist-admin__modal-backdrop">
          <div class="ip-watchlist-admin__modal">
            <h3>{{i18n "admin.plugins.ip_watchlist.edit_ip_group"}}</h3>
            <p>
              <input
                type="text"
                value={{@controller.editIpGroupName}}
                {{on "input" @controller.updateEditIpGroupName}}
                class="ip-watchlist-admin__add-ip"
              />
            </p>
            <p>{{i18n "admin.plugins.ip_watchlist.linked_groups"}}:</p>
            <div class="ip-watchlist-admin__group-list">
              {{#each @controller.ipGroupsData.discourse_groups as |dg|}}
                <label class="ip-watchlist-admin__group-option">
                  <input
                    type="checkbox"
                    checked={{includes @controller.editIpGroupDiscourseGroupIds dg.id}}
                    {{on "change" (fn @controller.toggleEditIpGroupDiscourseGroup dg.id)}}
                  />
                  {{dg.name}}
                </label>
              {{/each}}
            </div>
            <div class="ip-watchlist-admin__modal-actions">
              <DButton
                class="btn-default"
                @action={{@controller.cancelEditIpGroup}}
                @label="cancel"
              />
              <DButton
                class="btn-primary"
                @action={{@controller.saveEditIpGroup}}
                @translatedLabel={{i18n "admin.plugins.ip_watchlist.save"}}
              />
            </div>
          </div>
        </div>
      {{/if}}

      {{#if @controller.promoteEntry}}
        <div class="ip-watchlist-admin__modal-backdrop">
          <div class="ip-watchlist-admin__modal">
            <h3>{{i18n "admin.plugins.ip_watchlist.promote_title"}}</h3>
            <p><code>{{@controller.promoteEntry.ip_address}}</code></p>
            <p>{{i18n "admin.plugins.ip_watchlist.select_groups"}}</p>
            <div class="ip-watchlist-admin__group-list">
              {{#each @controller.model.groups as |group|}}
                <label class="ip-watchlist-admin__group-option">
                  <input
                    type="checkbox"
                    checked={{includes @controller.selectedGroupIds group.id}}
                    {{on "change" (fn @controller.toggleGroup group.id)}}
                  />
                  {{group.name}}
                </label>
              {{/each}}
            </div>
            <div class="ip-watchlist-admin__modal-actions">
              <DButton
                class="btn-default"
                @action={{@controller.closePromote}}
                @label="cancel"
              />
              <DButton
                class="btn-primary"
                @action={{@controller.savePromote}}
                @translatedLabel={{i18n "admin.plugins.ip_watchlist.save_promote"}}
              />
            </div>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
);
