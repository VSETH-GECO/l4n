require 'test_helper'

module Unit
  module Operations
    module Admin
      module SeatMap
        class UpdateTest < ApplicationTest
          setup do
            store :lan_party, create_lan_party
          end

          def test_update_as_lan_party_admin
            user = create_user
            create_user_permission(user, :lan_party_admin, :manage)

            as_user(user.reload) do
              run_op! ::Operations::Admin::SeatMap::Update,
                      lan_party_id: fetch(:lan_party).id.to_s,
                      seat_map:     { canvas_height: '500', canvas_width: '800' }
            end

            seat_map = fetch(:lan_party).seat_map.reload

            assert_equal 500, seat_map.canvas_height
            assert_equal 800, seat_map.canvas_width
          end

          def test_update_as_readonly_lan_party_admin
            user = create_user
            create_user_permission(user, :lan_party_admin, :readonly)

            as_user(user.reload) do
              assert_raises CanCan::AccessDenied do
                run_op! ::Operations::Admin::SeatMap::Update,
                        lan_party_id: fetch(:lan_party).id.to_s,
                        seat_map:     { canvas_height: '500' }
              end
            end
          end
        end
      end
    end
  end
end
