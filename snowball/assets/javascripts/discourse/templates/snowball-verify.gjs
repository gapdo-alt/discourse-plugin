import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

function eq(a, b) {
  return a === b;
}

function not(value) {
  return !value;
}

// Plain-text employee id: 8 digits shown as three groups separated by a single
// space (e.g. "00 575 561").  In a .gjs template a function in scope is called
// with the positional arguments one by one (not as an array like the classic
// `helper()` signature), so this must not destructure its argument.
function formatEmployeeId(id) {
  const s = String(id ?? "")
    .replace(/\D/g, "")
    .padStart(8, "0");
  if (s.length !== 8) {
    return id;
  }
  return `${s.slice(0, 2)} ${s.slice(2, 5)} ${s.slice(5, 8)}`;
}

export default RouteTemplate(
  <template>
    <div class="snowball-page">
      <div class="snowball-wrap">
        <h1>{{i18n "snowball.verify_title"}}</h1>
        <p class="snowball-muted">{{i18n "snowball.verify_desc"}}</p>

        {{#if (eq @controller.step "start")}}
          <div class="snowball-card">
            <p class="snowball-muted">
              {{i18n "snowball.current_user"}}
              <strong>{{@controller.currentUser.username}}</strong>
            </p>
            {{#if @controller.expiredNotice}}
              <p class="snowball-error">{{@controller.expiredNotice}}</p>
            {{/if}}
            {{#if @controller.remainingText}}
              <p class="snowball-muted snowball-remaining">{{@controller.remainingText}}</p>
            {{/if}}
            <button
              class="btn btn-primary snowball-btn"
              type="button"
              disabled={{@controller.loading}}
              {{on "click" @controller.startChallenge}}
            >
              {{#if @controller.loading}}
                {{i18n "snowball.loading"}}
              {{else}}
                {{i18n "snowball.start"}}
              {{/if}}
            </button>
            {{#if @controller.errorMessage}}
              <p class="snowball-error">{{@controller.errorMessage}}</p>
            {{/if}}
          </div>
        {{/if}}

        {{#if (eq @controller.step "quiz")}}
          <div class="snowball-card">
            <div class={{@controller.timerClass}}>
              <span class="snowball-timer-label">{{i18n "snowball.countdown"}}</span>
              {{@controller.timerLeft}}
            </div>

            {{#each @controller.employeeIds as |id index|}}
              <div class="snowball-q-row" data-snowball-row={{id}}>
                <span class="snowball-q-id">{{formatEmployeeId id}}</span>
                <label class="snowball-q-label">{{i18n "snowball.surname"}}</label>
                <input
                  type="text"
                  class="snowball-input"
                  data-snowball-input={{id}}
                  autocomplete="off"
                  autocapitalize="off"
                  value={{get @controller.answers id}}
                  disabled={{get @controller.resignedMap id}}
                  {{on "compositionstart" (fn @controller.compositionStart id)}}
                  {{on "compositionend" (fn @controller.compositionEnd id)}}
                  {{on "input" (fn @controller.updateAnswer id)}}
                  {{on "keydown" (fn @controller.answerKeydown id index)}}
                />
                <label class="snowball-checkbox">
                  <input
                    type="checkbox"
                    checked={{get @controller.resignedMap id}}
                    {{on "change" (fn @controller.setResigned id)}}
                  />
                  {{i18n "snowball.resigned"}}
                </label>
              </div>
            {{/each}}

            <button
              class="btn btn-primary snowball-btn snowball-btn-submit"
              type="button"
              disabled={{not @controller.canSubmit}}
              {{on "click" @controller.submitAnswers}}
            >
              {{#if @controller.loading}}
                {{i18n "snowball.submitting"}}
              {{else}}
                {{i18n "snowball.submit"}}
              {{/if}}
            </button>

            {{#if @controller.errorMessage}}
              <p class="snowball-error">{{@controller.errorMessage}}</p>
            {{/if}}
          </div>
        {{/if}}

        {{#if (eq @controller.step "result")}}
          <div class="snowball-card">
            <div class="snowball-result {{if @controller.passed 'pass' 'fail'}}">
              {{@controller.resultMessage}}
            </div>
            {{#if @controller.discoursePromoted}}
              <p class="snowball-muted">{{i18n "snowball.promoted_hint"}}</p>
            {{/if}}
            <button
              class="btn btn-default snowball-btn secondary"
              type="button"
              {{on "click" @controller.resetFlow}}
            >
              {{i18n "snowball.back"}}
            </button>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
);
