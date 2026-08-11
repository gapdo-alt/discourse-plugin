# frozen_string_literal: true

module ::IpWatchlist
  class AdminController < ::Admin::AdminController
    requires_plugin ::IpWatchlist::PLUGIN_NAME

    def index
      entries =
        IpWatchlistEntry
          .order(last_seen_at: :desc)
          .limit(500)

      if params[:q].present?
        q = "%#{params[:q].to_s.strip}%"
        entries =
          entries.where(
            "ip_address::text ILIKE :q OR organization ILIKE :q OR hostname ILIKE :q OR referrer ILIKE :q",
            q: q,
          )
      end

      render_json_dump(
        entries: ActiveModel::ArraySerializer.new(
          entries,
          each_serializer: IpWatchlistEntrySerializer,
          root: false,
        ),
        enforcements: ActiveModel::ArraySerializer.new(
          IpWatchlistEnforcement.includes(:group).order(updated_at: :desc).limit(500),
          each_serializer: IpWatchlistEnforcementSerializer,
          root: false,
        ),
        groups: Group.order(:name).limit(1000).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      )
    end

    def create_entry
      ip = IpWatchlistEntry.normalize_ip(params.require(:ip_address))
      raise Discourse::InvalidParameters.new(:ip_address) if ip.blank?

      entry =
        IpWatchlistEntry.find_or_initialize_by(ip_address: ip)
      entry.reason = IpWatchlist::Evaluator::REASON_MANUAL if entry.new_record?
      entry.created_by_id ||= current_user.id
      entry.first_seen_at ||= Time.zone.now
      entry.last_seen_at = Time.zone.now
      entry.hit_count = [entry.hit_count.to_i, 1].max
      entry.save!

      render_json_dump(entry: IpWatchlistEntrySerializer.new(entry, root: false))
    end

    def destroy_entry
      entry = IpWatchlistEntry.find(params[:id])
      entry.destroy!
      render json: success_json
    end

    def promote
      entry = IpWatchlistEntry.find(params[:id])
      group_ids = Array(params[:group_ids]).map(&:to_i).uniq
      raise Discourse::InvalidParameters.new(:group_ids) if group_ids.blank?

      groups = Group.where(id: group_ids)
      raise Discourse::InvalidParameters.new(:group_ids) if groups.count != group_ids.size

      enforcements =
        groups.map do |group|
          enforcement =
            IpWatchlistEnforcement.find_or_initialize_by(
              ip_address: entry.ip_address,
              group_id: group.id,
            )
          enforcement.enabled = true
          enforcement.created_by_id ||= current_user.id
          enforcement.save!
          enforcement
        end

      IpWatchlist::GroupAssigner.backfill_ip!(
        ip_address: entry.ip_address.to_s,
        group_ids: group_ids,
      )

      render_json_dump(
        enforcements:
          ActiveModel::ArraySerializer.new(
            enforcements,
            each_serializer: IpWatchlistEnforcementSerializer,
            root: false,
          ),
      )
    end

    def enforcements
      rows = IpWatchlistEnforcement.includes(:group).order(updated_at: :desc).limit(500)
      render_json_dump(
        enforcements:
          ActiveModel::ArraySerializer.new(
            rows,
            each_serializer: IpWatchlistEnforcementSerializer,
            root: false,
          ),
      )
    end

    def create_enforcement
      ip = IpWatchlistEnforcement.normalize_ip(params.require(:ip_address))
      group_id = params.require(:group_id).to_i
      raise Discourse::InvalidParameters.new(:ip_address) if ip.blank?
      raise Discourse::NotFound if Group.find_by(id: group_id).blank?

      enforcement =
        IpWatchlistEnforcement.find_or_initialize_by(ip_address: ip, group_id: group_id)
      enforcement.enabled = ActiveModel::Type::Boolean.new.cast(params.fetch(:enabled, true))
      enforcement.created_by_id ||= current_user.id
      enforcement.save!

      if enforcement.enabled?
        IpWatchlist::GroupAssigner.backfill_ip!(ip_address: ip, group_ids: [group_id])
      end

      render_json_dump(enforcement: IpWatchlistEnforcementSerializer.new(enforcement, root: false))
    end

    def update_enforcement
      enforcement = IpWatchlistEnforcement.find(params[:id])

      if params.key?(:enabled)
        enforcement.enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
      end

      if params[:group_id].present?
        group_id = params[:group_id].to_i
        raise Discourse::NotFound if Group.find_by(id: group_id).blank?
        enforcement.group_id = group_id
      end

      enforcement.save!

      if enforcement.enabled? && enforcement.saved_change_to_enabled?
        IpWatchlist::GroupAssigner.backfill_ip!(
          ip_address: enforcement.ip_address.to_s,
          group_ids: [enforcement.group_id],
        )
      end

      render_json_dump(enforcement: IpWatchlistEnforcementSerializer.new(enforcement, root: false))
    end

    def destroy_enforcement
      enforcement = IpWatchlistEnforcement.find(params[:id])
      enforcement.destroy!
      render json: success_json
    end

    # ── IP Groups ──────────────────────────────────────────────

    def ip_groups
      groups =
        IpWatchlistGroup
          .includes(:discourse_group_links, :memberships)
          .order(:name)

      render_json_dump(
        ip_groups:
          ActiveModel::ArraySerializer.new(
            groups,
            each_serializer: IpWatchlistGroupSerializer,
            root: false,
          ),
        discourse_groups:
          Group.order(:name).limit(1000).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      )
    end

    def create_ip_group
      name = params.require(:name).strip
      discourse_group_ids = Array(params[:discourse_group_ids]).map(&:to_i).uniq

      ip_group = IpWatchlistGroup.new(name: name, created_by: current_user)
      ip_group.save!

      sync_discourse_groups!(ip_group, discourse_group_ids)

      render_json_dump(ip_group: IpWatchlistGroupSerializer.new(ip_group.reload, root: false))
    end

    def update_ip_group
      ip_group = IpWatchlistGroup.find(params[:id])
      ip_group.name = params[:name].strip if params[:name].present?
      ip_group.save!

      if params.key?(:discourse_group_ids)
        discourse_group_ids = Array(params[:discourse_group_ids]).map(&:to_i).uniq
        sync_discourse_groups!(ip_group, discourse_group_ids)

        backfill_ip_group!(ip_group)
      end

      render_json_dump(ip_group: IpWatchlistGroupSerializer.new(ip_group.reload, root: false))
    end

    def destroy_ip_group
      ip_group = IpWatchlistGroup.find(params[:id])
      ip_group.destroy!
      render json: success_json
    end

    def add_ip_to_group
      ip_group = IpWatchlistGroup.find(params[:id])
      ip = normalize_ip!(params.require(:ip_address))

      membership =
        ip_group.memberships.find_or_initialize_by(ip_address: ip)
      membership.created_by_id ||= current_user.id
      membership.save!

      backfill_ip_for_group!(ip, ip_group)

      render_json_dump(ip_group: IpWatchlistGroupSerializer.new(ip_group.reload, root: false))
    end

    def remove_ip_from_group
      ip_group = IpWatchlistGroup.find(params[:id])
      ip = normalize_ip!(params.require(:ip_address))

      ip_group.memberships.where(ip_address: ip).destroy_all

      render json: success_json
    end

    # Called from the IP lookup popup to list groups + membership status for an IP
    def ip_groups_for_ip
      ip = normalize_ip!(params.require(:ip_address))

      all_groups =
        IpWatchlistGroup
          .includes(:discourse_group_links, :memberships)
          .order(:name)

      member_group_ids =
        IpWatchlistGroupMembership.where(ip_address: ip).pluck(:ip_watchlist_group_id)

      target_subnet = subnet_prefix(ip)

      render_json_dump(
        ip_groups:
          all_groups.map do |g|
            member_ips = g.memberships.pluck(:ip_address).map(&:to_s)
            is_member = member_group_ids.include?(g.id)

            same_subnet_ips =
              if !is_member && target_subnet
                member_ips.select { |mip| subnet_prefix(mip) == target_subnet }
              else
                []
              end

            {
              id: g.id,
              name: g.name,
              is_member: is_member,
              discourse_group_names: g.discourse_groups.pluck(:name),
              same_subnet_ips: same_subnet_ips,
              has_same_subnet: same_subnet_ips.present?,
            }
          end,
      )
    end

    # Quick add IP to one or more IP groups from the IP lookup popup
    def quick_add_ip
      ip = normalize_ip!(params.require(:ip_address))
      ip_group_ids = Array(params.require(:ip_group_ids)).map(&:to_i).uniq

      ip_group_ids.each do |gid|
        ip_group = IpWatchlistGroup.find(gid)
        membership = ip_group.memberships.find_or_initialize_by(ip_address: ip)
        membership.created_by_id ||= current_user.id
        membership.save!
        backfill_ip_for_group!(ip, ip_group)
      end

      render json: success_json
    end

    private

    def sync_discourse_groups!(ip_group, discourse_group_ids)
      ip_group.discourse_group_links.where.not(group_id: discourse_group_ids).destroy_all

      discourse_group_ids.each do |gid|
        next if Group.find_by(id: gid).blank?
        ip_group.discourse_group_links.find_or_create_by!(group_id: gid)
      end
    end

    def backfill_ip_group!(ip_group)
      group_ids = ip_group.discourse_group_links.pluck(:group_id)
      return if group_ids.blank?

      ip_group.memberships.pluck(:ip_address).each do |ip|
        IpWatchlist::GroupAssigner.backfill_ip!(ip_address: ip.to_s, group_ids: group_ids)
      end
    end

    def backfill_ip_for_group!(ip, ip_group)
      group_ids = ip_group.discourse_group_links.pluck(:group_id)
      return if group_ids.blank?

      IpWatchlist::GroupAssigner.backfill_ip!(ip_address: ip.to_s, group_ids: group_ids)
    end

    def normalize_ip!(raw)
      ip = IpWatchlistEntry.normalize_ip(raw)
      raise Discourse::InvalidParameters.new(:ip_address) if ip.blank?
      ip
    end

    # Returns the /24 (IPv4) or /48 (IPv6) prefix string for subnet comparison
    def subnet_prefix(ip_str)
      addr = IPAddr.new(ip_str.to_s)
      if addr.ipv4?
        addr.mask(24).to_s
      else
        addr.mask(48).to_s
      end
    rescue IPAddr::InvalidAddressError
      nil
    end
  end
end
