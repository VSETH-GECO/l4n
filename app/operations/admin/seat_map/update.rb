module Operations::Admin::SeatMap
  class Update < RailsOps::Operation::Model::Update
    schema3 do
      str! :lan_party_id
      hsh? :seat_map do
        int? :background_height, cast_str: true
        int? :background_width, cast_str: true
        int? :canvas_height, cast_str: true
        int? :canvas_width, cast_str: true
        obj? :background
      end
    end

    model ::SeatMap

    private

    def find_model
      LanParty.find(osparams.lan_party_id).seat_map
    end
  end
end
