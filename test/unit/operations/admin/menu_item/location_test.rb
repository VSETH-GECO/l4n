require 'test_helper'

module Unit
  module Operations
    module Admin
      module MenuItem
        class LocationTest < ApplicationTest
          setup do
            store :context, RailsOps::Context.new(user: create_user)
          end

          def test_link_defaults_to_navbar
            item = ::Operations::Admin::MenuItem::CreateLink.run!(fetch(:context),
                                                                  menu_link_item: { title: 'News', sort: '0', page_attr: 'news' }).model.reload

            assert item.navbar?
          end

          def test_create_footer_link
            item = ::Operations::Admin::MenuItem::CreateLink.run!(fetch(:context),
                                                                  menu_link_item: {
                                                                    title: 'Imprint', sort: '0', location: 'footer', external_link: 'https://example.com'
                                                                  }).model.reload

            assert item.footer?
            assert_equal [item.id], Queries::MenuItem::FindActiveTopElements.call(location: 'footer').ids
            assert_empty Queries::MenuItem::FindActiveTopElements.call(location: 'navbar')
          end

          def test_footer_link_cannot_have_parent
            dropdown = ::MenuDropdownItem.create!(title: 'More', sort: 0, visible: true)

            assert_raises ActiveRecord::RecordInvalid do
              ::Operations::Admin::MenuItem::CreateLink.run!(fetch(:context),
                                                             menu_link_item: {
                                                               title: 'Imprint', sort: '0', location: 'footer', parent_id: dropdown.id.to_s, page_attr: 'news'
                                                             })
            end
          end

          def test_dropdown_cannot_be_in_footer
            dropdown = ::MenuDropdownItem.new(title: 'More', sort: 0, visible: true, location: 'footer')

            assert_not dropdown.valid?
            assert dropdown.errors.key?(:location)
          end

          def test_invalid_location
            item = ::MenuLinkItem.new(title: 'News', sort: 0, static_page_name: 'news', location: 'sidebar')

            assert_not item.valid?
            assert item.errors.key?(:location)
          end

          def test_move_link_to_footer
            item = ::MenuLinkItem.create!(title: 'News', sort: 0, static_page_name: 'news')
            ::Operations::Admin::MenuItem::Update.run!(fetch(:context),
                                                       id: item.id.to_s, menu_link_item: { location: 'footer', page_attr: 'news' })

            assert item.reload.footer?
          end
        end
      end
    end
  end
end
