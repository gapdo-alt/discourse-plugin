import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class SnowballVerifyController extends Controller {
  // The template renders {{this.currentUser.username}}, so the service has to
  // be injected on the controller as well as the route.
  @service currentUser;

  @tracked step = "start";
  @tracked loading = false;
  @tracked errorMessage = "";
  @tracked challengeId = "";
  @tracked expiresAt = 0;
  @tracked employeeIds = [];
  @tracked answers = {};
  @tracked resignedMap = {};
  @tracked timerLeft = 0;
  @tracked resultMessage = "";
  @tracked passed = false;
  @tracked discoursePromoted = false;
  // Payload of /snowball/status (verification state + remaining attempts)
  @tracked status = null;

  timerHandle = null;

  // Fetched asynchronously (the request hits the upstream API) so the page
  // paints immediately and the remaining count simply pops in afterwards.
  constructor() {
    super(...arguments);
    this._loadStatus();
  }

  async _loadStatus() {
    try {
      this.status = await ajax("/snowball/status");
    } catch {
      // ignore -- the verification page still works without this payload
    }
  }

  get timerClass() {
    return this.timerLeft > 30 ? "snowball-timer ok" : "snowball-timer";
  }

  get canSubmit() {
    return !this.loading && this.timerLeft > 0;
  }

  // "今日剩余 2 次 · 本周剩余 2 次" (or the unlimited wording)
  get remainingText() {
    const remaining = this.status?.remaining_attempts;
    if (!remaining) {
      return "";
    }

    const parts = [];
    if (remaining.daily !== null && remaining.daily !== undefined) {
      parts.push(i18n("snowball.remaining_daily", { count: remaining.daily }));
    }
    if (remaining.weekly !== null && remaining.weekly !== undefined) {
      parts.push(i18n("snowball.remaining_weekly", { count: remaining.weekly }));
    }

    return parts.length
      ? parts.join(i18n("snowball.remaining_separator"))
      : i18n("snowball.remaining_unlimited");
  }

  get expiredNotice() {
    return this.status?.expired ? i18n("snowball.expired_notice") : "";
  }

  _applyRemaining(payload) {
    if (payload?.remaining_attempts) {
      this.status = { ...(this.status || {}), remaining_attempts: payload.remaining_attempts };
    }
  }

  @action
  async startChallenge() {
    this.errorMessage = "";
    this.loading = true;
    try {
      const data = await ajax("/snowball/challenge", { type: "POST" });
      this._applyRemaining(data);
      this.challengeId = data.challenge_id;
      this.expiresAt = data.expires_at;
      this.employeeIds = data.employee_ids || [];
      this.answers = {};
      this.resignedMap = {};
      this.step = "quiz";
      this._startTimer();
      requestAnimationFrame(() => {
        document.querySelector("[data-snowball-input]")?.focus();
      });
    } catch (e) {
      this._applyRemaining(e.jqXHR?.responseJSON);
      this.errorMessage = this._extractError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateAnswer(id, event) {
    // One answer = one letter (Chinese character, Latin letter, ...).  `maxlength`
    // only caps the length, so drop digits/punctuation/spaces as well and keep
    // the field itself in sync.
    const raw = event.target.value ?? "";
    const cleaned = [...raw]
      .filter((char) => /\p{L}/u.test(char))
      .slice(0, 1)
      .join("");

    if (event.target.value !== cleaned) {
      event.target.value = cleaned;
    }

    this.answers = { ...this.answers, [id]: cleaned };
    this._clearUnansweredHighlight(id);
  }

  @action
  setResigned(id, event) {
    const checked = event.target.checked;
    this.resignedMap = { ...this.resignedMap, [id]: checked };
    if (checked) {
      this.answers = { ...this.answers, [id]: "" };
      this._clearUnansweredHighlight(id);
    }
  }

  @action
  answerKeydown(id, index, event) {
    if (event.key !== "Enter" || event.isComposing) {
      return;
    }
    event.preventDefault();
    const nextId = this.employeeIds[index + 1];
    if (nextId) {
      document.querySelector(`[data-snowball-input="${nextId}"]`)?.focus();
      return;
    }
    document.querySelector(".snowball-btn-submit")?.focus();
  }

  @action
  async submitAnswers() {
    if (!this.canSubmit) {
      return;
    }

    this.errorMessage = "";

    const unanswered = this._findUnansweredIds();
    if (unanswered.length > 0) {
      this._markUnanswered(unanswered);
      this.errorMessage = i18n("snowball.incomplete", { count: unanswered.length });
      document.querySelector(`[data-snowball-input="${unanswered[0]}"]`)?.focus();
      return;
    }

    this.loading = true;

    const answers = this.employeeIds.map((id) => {
      if (this.resignedMap[id]) {
        return { employee_id: id, resigned: true };
      }
      return { employee_id: id, surname: (this.answers[id] || "").trim() };
    });

    try {
      const data = await ajax("/snowball/verify", {
        type: "POST",
        data: {
          challenge_id: this.challengeId,
          answers,
        },
      });

      this._stopTimer();
      this._applyRemaining(data);
      this.passed = !!data.passed;
      this.discoursePromoted = !!data.discourse_promoted;
      this.resultMessage =
        data.message ||
        (this.passed ? i18n("snowball.result_pass") : i18n("snowball.result_fail"));
      this.step = "result";
    } catch (e) {
      this._applyRemaining(e.jqXHR?.responseJSON);
      this.errorMessage = this._extractError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  resetFlow() {
    this._stopTimer();
    this.step = "start";
    this.errorMessage = "";
    this.resultMessage = "";
    this.passed = false;
    this.discoursePromoted = false;
  }

  _startTimer() {
    this._stopTimer();
    const tick = () => {
      const left = Math.max(0, Math.ceil((this.expiresAt - Date.now()) / 1000));
      this.timerLeft = left;
      if (left <= 0) {
        this._stopTimer();
        this.errorMessage = i18n("snowball.timeout");
      }
    };
    tick();
    this.timerHandle = setInterval(tick, 250);
  }

  _stopTimer() {
    if (this.timerHandle) {
      clearInterval(this.timerHandle);
      this.timerHandle = null;
    }
  }

  _extractError(e) {
    const json = e.jqXHR?.responseJSON;
    // Attempt limit reached -- render the localized wording client side.
    const limitKeys = {
      snowball_daily_limit: "snowball.limit_daily",
      snowball_weekly_limit: "snowball.limit_weekly",
    };
    if (json?.error_type && limitKeys[json.error_type]) {
      return i18n(limitKeys[json.error_type], { limit: json.limit });
    }
    if (json?.error) {
      return json.error;
    }
    if (json?.errors?.length) {
      return json.errors[0];
    }
    if (json?.message) {
      return json.message;
    }
    return e.message || i18n("snowball.generic_error");
  }

  _findUnansweredIds() {
    return this.employeeIds.filter((id) => {
      if (this.resignedMap[id]) {
        return false;
      }
      return !(this.answers[id] || "").trim();
    });
  }

  _markUnanswered(ids) {
    document.querySelectorAll(".snowball-q-row").forEach((row) => {
      row.classList.remove("unanswered");
    });
    for (const id of ids) {
      document
        .querySelector(`[data-snowball-row="${id}"]`)
        ?.classList.add("unanswered");
    }
  }

  _clearUnansweredHighlight(id) {
    document
      .querySelector(`[data-snowball-row="${id}"]`)
      ?.classList.remove("unanswered");
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._stopTimer();
  }
}
