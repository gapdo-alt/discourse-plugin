# frozen_string_literal: true

module Snowball
  class AdminController < ::Admin::AdminController
    requires_plugin ::Snowball::PLUGIN_NAME

    # Rows returned per page by the library viewers.  The pages are meant for
    # spot checks, not for exporting the table, so the cap is deliberately low.
    LIBRARY_PER_PAGE = 50
    LIBRARY_MAX_PER_PAGE = 200

    # GET /admin/snowball/seeds -- library statistics (never the data itself)
    def seeds
      render json: SnowballSeedImport.stats
    end

    # GET /admin/snowball/library/seeds -- the seed rows themselves, paginated
    def library_seeds
      scope = SnowballSeed.order(:employee_id)

      render_library(scope) do |seed|
        {
          employee_id: seed.employee_id,
          surname: seed.surname,
          confidence: seed.confidence,
          status: seed.status,
          resigned_signals: seed.resigned_signals,
          in_active_pool: seed.in_active_pool,
          updated_at: seed.updated_at&.iso8601,
        }
      end
    end

    # GET /admin/snowball/library/observations -- probe surname votes
    def library_observations
      scope = SnowballObservation.order(total: :desc, employee_id: :asc)

      render_library(scope) do |observation|
        {
          employee_id: observation.employee_id,
          votes: observation.votes || {},
          total: observation.total,
          updated_at: observation.updated_at&.iso8601,
        }
      end
    end

    # GET /admin/snowball/library/resigned_observations -- probe resigned votes
    def library_resigned_observations
      scope = SnowballResignedObservation.order(resigned_votes: :desc, employee_id: :asc)

      render_library(scope) do |observation|
        {
          employee_id: observation.employee_id,
          resigned_votes: observation.resigned_votes,
          probe_weight: observation.probe_weight,
          range_radius: observation.range_radius,
          updated_at: observation.updated_at&.iso8601,
        }
      end
    end

    # POST /admin/snowball/seeds -- import a JSON export (uploaded from the
    # admin page).  Accepts the upstream admin export shape.
    def import
      payload = params.require(:payload)
      result = SnowballSeedImport.call(payload)

      render json: { imported: result, stats: SnowballSeedImport.stats }
    rescue SnowballSeedImport::Error => e
      render_json_error(e.message, status: 400)
    end

    # DELETE /admin/snowball/seeds -- wipe the imported library
    def destroy_all
      SnowballSeed.delete_all
      SnowballObservation.delete_all
      SnowballResignedObservation.delete_all
      SnowballChallenge.delete_all

      render json: { ok: true, stats: SnowballSeedImport.stats }
    end

    private

    # Shared paging + optional employee-id filter for the three library lists.
    # The filter is reduced to digits before it reaches SQL, so it can never
    # change the shape of the statement (and the ids are digits by definition).
    def render_library(scope)
      digits = params[:q].to_s.gsub(/\D/, "")
      scope = scope.where("employee_id LIKE ?", "%#{digits}%") if digits.present?

      page = [params[:page].to_i, 1].max
      per_page = params[:per_page].to_i
      per_page = LIBRARY_PER_PAGE if per_page <= 0
      per_page = LIBRARY_MAX_PER_PAGE if per_page > LIBRARY_MAX_PER_PAGE

      total = scope.count
      rows = scope.offset((page - 1) * per_page).limit(per_page)

      render json: {
        total: total,
        page: page,
        per_page: per_page,
        items: rows.map { |row| yield row },
      }
    end
  end
end
