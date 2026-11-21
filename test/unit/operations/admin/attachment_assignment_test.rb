require 'test_helper'

module Unit
  module Operations
    module Admin
      # Regression test: rails_ops casts the model with `becomes` for
      # authorization, which (since Rails 8.1) used to steal pending
      # ActiveStorage attachment changes. See
      # lib/ext/rails_ops/attachment_authorization_ext.rb.
      class AttachmentAssignmentTest < ApplicationTest
        PNG_1X1 = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')

        setup do
          user = create_user
          create_user_permission(user, :upload_admin, :manage)
          create_user_permission(user, :design_admin, :manage)
          store :admin, user.reload
        end

        def test_create_attaches_file
          op = as_user fetch(:admin) do
            run_op! ::Operations::Admin::Upload::Create, upload: { file: uploaded_file('geco.svg', 'image/svg+xml', '<svg xmlns="http://www.w3.org/2000/svg"/>') }
          end

          upload = ::Upload.find(op.model.id)
          assert_predicate upload.file, :attached?
          assert_equal 'geco.svg', upload.file.filename.to_s
        end

        def test_update_replaces_file
          logo = ::FooterLogo.create!(sort: 0, visible: true, file: uploaded_file('old.png', 'image/png', PNG_1X1))

          as_user fetch(:admin) do
            run_op! ::Operations::Admin::FooterLogo::Update, id: logo.id, footer_logo: { file: uploaded_file('new.png', 'image/png', PNG_1X1) }
          end

          assert_equal 'new.png', logo.reload.file.filename.to_s
        end

        private

        def uploaded_file(filename, content_type, content)
          Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
        end
      end
    end
  end
end
