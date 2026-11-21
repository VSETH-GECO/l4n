require 'test_helper'

module Unit
  module Operations
    module Admin
      module Settings
        class UpdateTest < ApplicationTest
          setup do
            user = create_user
            create_user_permission(user, :system_admin, :manage)
            store :admin, user.reload
          end

          def test_set_and_clear_logo_url
            assert_nil AppConfig.logo_url

            as_user fetch(:admin) do
              run_op! ::Operations::Admin::Settings::Update, app_config: { logo_url: 'https://example.com/logo.png' }
            end
            assert_equal 'https://example.com/logo.png', AppConfig.logo_url

            as_user fetch(:admin) do
              run_op! ::Operations::Admin::Settings::Update, app_config: { logo_url: '' }
            end
            assert_predicate AppConfig.logo_url, :blank?
          end

          def test_requires_system_admin_permission
            assert_raises CanCan::AccessDenied do
              as_user create_user(email: 'other@example.com', username: 'other') do
                run_op! ::Operations::Admin::Settings::Update, app_config: { logo_url: 'https://example.com/logo.png' }
              end
            end
          end
        end
      end
    end
  end
end
