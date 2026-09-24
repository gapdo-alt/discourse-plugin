import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

// Employee ids are stored as eight digits; show them in the same
// "00 000 000" shape the quiz uses so both views can be compared by eye.
function formatId(value) {
  const digits = String(value ?? "")
    .replace(/\D/g, "")
    .padStart(8, "0");

  if (digits.length !== 8) {
    return value;
  }

  return `${digits.slice(0, 2)} ${digits.slice(2, 5)} ${digits.slice(5, 8)}`;
}

// Renders one library cell.  Called with positional arguments (row, column)
// because plain functions in a .gjs template are not array helpers.
function cell(row, column) {
  const value = row[column.key];

  switch (column.format) {
    case "id":
      return formatId(value);
    case "bool":
      return value ? "✓" : "—";
    case "time":
      return value ? String(value).slice(0, 19).replace("T", " ") : "—";
    case "weight":
      return Number(value ?? 0).toFixed(3);
    default:
      return value === null || value === undefined || value === "" ? "—" : String(value);
  }
}

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

      <div class="snowball-admin__library-buttons">
        <DButton
          class="btn-default"
          @action={{fn @controller.openLibrary "seeds"}}
          @translatedLabel={{i18n "admin.plugins.snowball.view_seeds"}}
        />
        <DButton
          class="btn-default"
          @action={{fn @controller.openLibrary "observations"}}
          @translatedLabel={{i18n "admin.plugins.snowball.view_observations"}}
        />
        <DButton
          class="btn-default"
          @action={{fn @controller.openLibrary "resigned_observations"}}
          @translatedLabel={{i18n "admin.plugins.snowball.view_resigned"}}
        />
      </div>

      {{#if @controller.libraryOpen}}
        <div class="snowball-admin__library">
          <div class="snowball-admin__library-head">
            <h3 class="snowball-admin__library-title">
              {{@controller.libraryTitle}}
              <span class="snowball-admin__library-count">
                {{i18n "admin.plugins.snowball.library_count" count=@controller.libraryTotal}}
              </span>
            </h3>

            <div class="snowball-admin__library-tools">
              <input
                type="search"
                class="snowball-admin__search"
                placeholder={{i18n "admin.plugins.snowball.library_search_placeholder"}}
                value={{@controller.libraryQuery}}
                {{on "input" @controller.onLibraryQuery}}
                {{on "keydown" @controller.onLibraryQueryKeydown}}
              />
              <DButton
                class="btn-default"
                @action={{@controller.searchLibrary}}
                @translatedLabel={{i18n "admin.plugins.snowball.library_search"}}
              />
              <DButton
                class="btn-default"
                @action={{@controller.closeLibrary}}
                @translatedLabel={{i18n "admin.plugins.snowball.library_close"}}
              />
            </div>
          </div>

          {{#if @controller.libraryLoading}}
            <p class="snowball-admin__library-empty">
              {{i18n "admin.plugins.snowball.library_loading"}}
            </p>
          {{else if @controller.libraryRows.length}}
            <div class="snowball-admin__table-wrap">
              <table class="snowball-admin__table">
                <thead>
                  <tr>
                    {{#each @controller.libraryColumns as |column|}}
                      <th>{{i18n column.label}}</th>
                    {{/each}}
                  </tr>
                </thead>
                <tbody>
                  {{#each @controller.libraryRows as |row|}}
                    <tr>
                      {{#each @controller.libraryColumns as |column|}}
                        <td>{{cell row column}}</td>
                      {{/each}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>

            <div class="snowball-admin__pager">
              <DButton
                class="btn-default btn-small"
                @action={{fn @controller.loadLibraryPage -1}}
                @translatedLabel={{i18n "admin.plugins.snowball.library_prev"}}
              />
              <span class="snowball-admin__pager-text">
                {{i18n "admin.plugins.snowball.library_page" page=@controller.libraryPage total=@controller.libraryPages}}
              </span>
              <DButton
                class="btn-default btn-small"
                @action={{fn @controller.loadLibraryPage 1}}
                @translatedLabel={{i18n "admin.plugins.snowball.library_next"}}
              />
            </div>
          {{else}}
            <p class="snowball-admin__library-empty">
              {{i18n "admin.plugins.snowball.library_empty"}}
            </p>
          {{/if}}
        </div>
      {{/if}}

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
