import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowIpWatchlistController extends Controller {
  @service dialog;
  @service toasts;

  @tracked activeTab = "watchlist";
  @tracked search = "";
  @tracked newIp = "";
  @tracked promoteEntry = null;
  @tracked selectedGroupIds = [];
  @tracked newEnforcementIp = "";
  @tracked newEnforcementGroupId = null;

  get reasonLabel() {
    return (reason) =>
      i18n(`admin.plugins.ip_watchlist.reasons.${reason}`) || reason;
  }

  @action
  switchTab(tab) {
    this.activeTab = tab;
  }

  @action
  async refreshData() {
    try {
      const url = this.search
        ? `/admin/plugins/ip-watchlist?q=${encodeURIComponent(this.search)}`
        : "/admin/plugins/ip-watchlist";
      this.model = await ajax(url);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async searchWatchlist(event) {
    event?.preventDefault?.();
    await this.refreshData();
  }

  @action
  async addIp(event) {
    event?.preventDefault?.();
    if (!this.newIp?.trim()) {
      return;
    }

    try {
      await ajax("/admin/plugins/ip-watchlist/entries", {
        type: "POST",
        data: { ip_address: this.newIp.trim() },
      });
      this.newIp = "";
      this.toasts.success({
        data: { message: i18n("admin.plugins.ip_watchlist.add_ip") },
        duration: "short",
      });
      await this.refreshData();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  deleteEntry(entry) {
    this.dialog.deleteConfirm({
      message: entry.ip_address,
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/ip-watchlist/entries/${entry.id}`, {
            type: "DELETE",
          });
          await this.refreshData();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  openPromote(entry) {
    this.promoteEntry = entry;
    this.selectedGroupIds = [...(entry.enforcement_group_ids || [])];
  }

  @action
  closePromote() {
    this.promoteEntry = null;
    this.selectedGroupIds = [];
  }

  @action
  toggleGroup(groupId, event) {
    const checked = event?.target?.checked;
    const id = Number(groupId);
    if (checked) {
      if (!this.selectedGroupIds.includes(id)) {
        this.selectedGroupIds = [...this.selectedGroupIds, id];
      }
    } else {
      this.selectedGroupIds = this.selectedGroupIds.filter((g) => g !== id);
    }
  }

  @action
  async savePromote() {
    if (!this.promoteEntry || this.selectedGroupIds.length === 0) {
      return;
    }

    try {
      await ajax(
        `/admin/plugins/ip-watchlist/entries/${this.promoteEntry.id}/promote`,
        {
          type: "POST",
          data: { group_ids: this.selectedGroupIds },
        }
      );
      this.closePromote();
      this.toasts.success({
        data: { message: i18n("admin.plugins.ip_watchlist.save_promote") },
        duration: "short",
      });
      await this.refreshData();
      this.activeTab = "enforcement";
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async toggleEnforcement(row) {
    try {
      await ajax(`/admin/plugins/ip-watchlist/enforcements/${row.id}`, {
        type: "PUT",
        data: { enabled: !row.enabled },
      });
      await this.refreshData();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  deleteEnforcement(row) {
    this.dialog.deleteConfirm({
      message: `${row.ip_address} → ${row.group_name}`,
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/ip-watchlist/enforcements/${row.id}`, {
            type: "DELETE",
          });
          await this.refreshData();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  async createEnforcement(event) {
    event?.preventDefault?.();
    if (!this.newEnforcementIp?.trim() || !this.newEnforcementGroupId) {
      return;
    }

    try {
      await ajax("/admin/plugins/ip-watchlist/enforcements", {
        type: "POST",
        data: {
          ip_address: this.newEnforcementIp.trim(),
          group_id: this.newEnforcementGroupId,
          enabled: true,
        },
      });
      this.newEnforcementIp = "";
      this.newEnforcementGroupId = null;
      await this.refreshData();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  updateNewIp(event) {
    this.newIp = event.target.value;
  }

  @action
  updateSearch(event) {
    this.search = event.target.value;
  }

  @action
  updateNewEnforcementIp(event) {
    this.newEnforcementIp = event.target.value;
  }

  @action
  updateNewEnforcementGroupId(event) {
    this.newEnforcementGroupId = event.target.value
      ? Number(event.target.value)
      : null;
  }

  // ── IP Groups ──────────────────────────────────────────

  @tracked ipGroupsData = null;
  @tracked newIpGroupName = "";
  @tracked newIpGroupDiscourseGroupIds = [];
  @tracked editingIpGroup = null;
  @tracked editIpGroupName = "";
  @tracked editIpGroupDiscourseGroupIds = [];
  @tracked addIpByGroupId = {};

  @action
  async loadIpGroups() {
    try {
      this.ipGroupsData = await ajax("/admin/plugins/ip-watchlist/ip-groups");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async switchToIpGroups() {
    this.activeTab = "ip_groups";
    await this.loadIpGroups();
  }

  @action
  updateNewIpGroupName(event) {
    this.newIpGroupName = event.target.value;
  }

  @action
  toggleNewIpGroupDiscourseGroup(groupId, event) {
    const id = Number(groupId);
    if (event?.target?.checked) {
      this.newIpGroupDiscourseGroupIds = [...this.newIpGroupDiscourseGroupIds, id];
    } else {
      this.newIpGroupDiscourseGroupIds = this.newIpGroupDiscourseGroupIds.filter((g) => g !== id);
    }
  }

  @action
  async createIpGroup() {
    if (!this.newIpGroupName.trim()) {
      return;
    }
    try {
      await ajax("/admin/plugins/ip-watchlist/ip-groups", {
        type: "POST",
        data: {
          name: this.newIpGroupName.trim(),
          discourse_group_ids: this.newIpGroupDiscourseGroupIds,
        },
      });
      this.newIpGroupName = "";
      this.newIpGroupDiscourseGroupIds = [];
      await this.loadIpGroups();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  startEditIpGroup(ipGroup) {
    this.editingIpGroup = ipGroup;
    this.editIpGroupName = ipGroup.name;
    this.editIpGroupDiscourseGroupIds = [...(ipGroup.discourse_group_ids || [])];
  }

  @action
  cancelEditIpGroup() {
    this.editingIpGroup = null;
  }

  @action
  updateEditIpGroupName(event) {
    this.editIpGroupName = event.target.value;
  }

  @action
  toggleEditIpGroupDiscourseGroup(groupId, event) {
    const id = Number(groupId);
    if (event?.target?.checked) {
      this.editIpGroupDiscourseGroupIds = [...this.editIpGroupDiscourseGroupIds, id];
    } else {
      this.editIpGroupDiscourseGroupIds = this.editIpGroupDiscourseGroupIds.filter((g) => g !== id);
    }
  }

  @action
  async saveEditIpGroup() {
    if (!this.editingIpGroup) {
      return;
    }
    try {
      await ajax(`/admin/plugins/ip-watchlist/ip-groups/${this.editingIpGroup.id}`, {
        type: "PUT",
        data: {
          name: this.editIpGroupName.trim(),
          discourse_group_ids: this.editIpGroupDiscourseGroupIds,
        },
      });
      this.editingIpGroup = null;
      await this.loadIpGroups();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  deleteIpGroup(ipGroup) {
    this.dialog.deleteConfirm({
      message: ipGroup.name,
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/ip-watchlist/ip-groups/${ipGroup.id}`, {
            type: "DELETE",
          });
          await this.loadIpGroups();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  updateAddIpForGroup(groupId, event) {
    this.addIpByGroupId = {
      ...this.addIpByGroupId,
      [groupId]: event.target.value,
    };
  }

  @action
  async addIpToGroup(ipGroup) {
    const ip = (this.addIpByGroupId[ipGroup.id] || "").trim();
    if (!ip) {
      return;
    }
    try {
      await ajax(`/admin/plugins/ip-watchlist/ip-groups/${ipGroup.id}/add-ip`, {
        type: "POST",
        data: { ip_address: ip },
      });
      this.addIpByGroupId = { ...this.addIpByGroupId, [ipGroup.id]: "" };
      await this.loadIpGroups();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async removeIpFromGroup(ipGroup, ip) {
    try {
      await ajax(`/admin/plugins/ip-watchlist/ip-groups/${ipGroup.id}/remove-ip`, {
        type: "DELETE",
        data: { ip_address: ip },
      });
      await this.loadIpGroups();
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
