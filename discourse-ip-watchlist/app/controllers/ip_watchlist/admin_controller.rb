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
  end
end
