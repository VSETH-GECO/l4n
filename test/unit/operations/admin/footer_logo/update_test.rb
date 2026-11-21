require 'test_helper'

module Unit
  module Operations
    module Admin
      module FooterLogo
        class UpdateTest < ApplicationTest
          PNG_1X1 = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')

          setup do
            user = create_user
            create_user_permission(user, :design_admin, :manage)
            store :admin, user.reload
            store :logo, ::FooterLogo.create!(sort: 0, visible: true, file: uploaded_file('light.png'))
          end

          def test_create_with_dark_file
            op = as_user fetch(:admin) do
              run_op! ::Operations::Admin::FooterLogo::Create, footer_logo: { file: uploaded_file('light.png'), file_dark: uploaded_file('dark.png') }
            end

            logo = ::FooterLogo.find(op.model.id)
            assert_equal 'light.png', logo.file.filename.to_s
            assert_equal 'dark.png', logo.file_dark.filename.to_s
          end

          def test_add_dark_file
            as_user fetch(:admin) do
              run_op! ::Operations::Admin::FooterLogo::Update, id: fetch(:logo).id, footer_logo: { file_dark: uploaded_file('dark.png') }
            end

            logo = fetch(:logo).reload
            assert_equal 'light.png', logo.file.filename.to_s
            assert_equal 'dark.png', logo.file_dark.filename.to_s
          end

          def test_remove_dark_file
            fetch(:logo).update!(file_dark: uploaded_file('dark.png'))

            as_user fetch(:admin) do
              run_op! ::Operations::Admin::FooterLogo::Update, id: fetch(:logo).id, footer_logo: { remove_file_dark: '1' }
            end

            logo = fetch(:logo).reload
            assert_not_predicate logo.file_dark, :attached?
            assert_predicate logo.file, :attached?
          end

          def test_unchecked_remove_keeps_dark_file
            fetch(:logo).update!(file_dark: uploaded_file('dark.png'))

            as_user fetch(:admin) do
              run_op! ::Operations::Admin::FooterLogo::Update, id: fetch(:logo).id, footer_logo: { remove_file_dark: '0' }
            end

            assert_predicate fetch(:logo).reload.file_dark, :attached?
          end

          def test_accepts_svg_files
            as_user fetch(:admin) do
              run_op! ::Operations::Admin::FooterLogo::Update, id: fetch(:logo).id, footer_logo: { file: svg_file('light.svg'), file_dark: svg_file('dark.svg') }
            end

            logo = fetch(:logo).reload
            assert_equal 'image/svg+xml', logo.file.content_type
            assert_equal 'image/svg+xml', logo.file_dark.content_type
          end

          def test_rejects_invalid_dark_file_type
            text_file = Rack::Test::UploadedFile.new(StringIO.new('hi'), 'text/plain', original_filename: 'x.txt')

            assert_raises ActiveRecord::RecordInvalid do
              as_user fetch(:admin) do
                run_op! ::Operations::Admin::FooterLogo::Update, id: fetch(:logo).id, footer_logo: { file_dark: text_file }
              end
            end
          end

          private

          def svg_file(filename)
            Rack::Test::UploadedFile.new(StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 2"/>'), 'image/svg+xml', original_filename: filename)
          end

          def uploaded_file(filename)
            Rack::Test::UploadedFile.new(StringIO.new(PNG_1X1), 'image/png', original_filename: filename)
          end
        end
      end
    end
  end
end
