import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class SnowballVerifyController extends Controller {
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

  timerHandle = null;

  get timerClass() {
    return this.timerLeft > 30 ? "snowball-timer ok" : "snowball-timer";
  }

  get canSubmit() {
    return !this.loading && this.timerLeft > 0;
  }

  @action
  async startChallenge() {
    this.errorMessage = "";
    this.loading = true;
    try {
      const data = await ajax("/snowball/challenge", { type: "POST" });
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
      this.errorMessage = this._extractError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateAnswer(id, event) {
    this.answers = { ...this.answers, [id]: event.target.value };
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
      this.passed = !!data.passed;
      this.discoursePromoted = !!data.discourse_promoted;
      this.resultMessage =
        data.message ||
        (this.passed ? i18n("snowball.result_pass") : i18n("snowball.result_fail"));
      this.step = "result";
    } catch (e) {
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
    if (json?.error) {
      return json.error;
    }
    if (json?.errors?.length) {
      return json.errors[0];
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
