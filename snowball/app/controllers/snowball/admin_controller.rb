# frozen_string_literal: true

module Snowball
  class AdminController < ::Admin::AdminController
    requires_plugin ::Snowball::PLUGIN_NAME

    # GET /admin/snowball/seeds -- library statistics (never the data itself)
    def seeds
      render json: SnowballSeedImport.stats
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
  end
end
