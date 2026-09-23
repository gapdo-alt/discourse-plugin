import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="snowball-admin admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "admin.plugins.snowball.title"}}
        @descriptionLabel={{i18n "admin.plugins.snowball.description"}}
      />

      <div class="snowball-admin__stats">
        <div class="snowball-admin__stat">
          <span class="snowball-admin__stat-label">{{i18n "admin.plugins.snowball.stat_seeds"}}</span>
          <strong>{{@controller.statSeeds}}</strong>
        </div>
        <div class="snowball-admin__stat">
          <span class="snowball-admin__stat-label">{{i18n "admin.plugins.snowball.stat_usable"}}</span>
          <strong>{{@controller.statUsable}}</strong>
        </div>
        <div class="snowball-admin__stat">
          <span class="snowball-admin__stat-label">{{i18n "admin.plugins.snowball.stat_observations"}}</span>
          <strong>{{@controller.statObservations}}</strong>
        </div>
        <div class="snowball-admin__stat">
          <span class="snowball-admin__stat-label">{{i18n "admin.plugins.snowball.stat_resigned"}}</span>
          <strong>{{@controller.statResigned}}</strong>
        </div>
        <div class="snowball-admin__stat">
          <span class="snowball-admin__stat-label">{{i18n "admin.plugins.snowball.stat_updated"}}</span>
          <strong>{{@controller.statUpdated}}</strong>
        </div>
      </div>

      <p class="snowball-muted">{{i18n "admin.plugins.snowball.upload_hint"}}</p>

      <div class="snowball-admin__upload">
        <input
          type="file"
          accept=".json,application/json"
          disabled={{@controller.importing}}
          {{on "change" @controller.onFileSelected}}
        />
        {{#if @controller.importing}}
          <span class="snowball-muted">{{i18n "admin.plugins.snowball.importing"}}</span>
        {{/if}}
      </div>

      {{#if @controller.lastResult}}
        <p class="snowball-admin__result">{{@controller.lastResult}}</p>
      {{/if}}

      <div class="snowball-admin__actions">
        <DButton
          class="btn-default"
          @action={{@controller.refresh}}
          @translatedLabel={{i18n "admin.plugins.snowball.refresh"}}
        />
        <DButton
          class="btn-danger"
          @action={{@controller.wipe}}
          @translatedLabel={{i18n "admin.plugins.snowball.wipe"}}
        />
      </div>
    </div>
  </template>
);
