module Grids
  module Admin
    class FooterLogos < ApplicationGrid
      scope do
        FooterLogo.order(:sort)
      end

      model FooterLogo

      column :logo_file, html: true do |footer_logo|
        footer_logo_image_tag footer_logo.file, :thumb
      end
      column :logo_file_dark, html: true do |footer_logo|
        next unless footer_logo.file_dark.attached?

        tag.div class: %w[p-1 bg-dark d-inline-block rounded] do
          footer_logo_image_tag footer_logo.file_dark, :thumb
        end
      end
      column :sort
      column :visible, html: ->(visible) { format_boolean visible }
      column :link
      column :'datagrid-actions', html: true, header: false do |footer_logo|
        tag.div class: %i[datagrid-actions-wrapper] do
          safe_join([
                      edit_button(footer_logo, namespace: %i[admin], size: :sm, icon_only: true),
                      delete_button(footer_logo, namespace: %i[admin], size: :sm, icon_only: true)
                    ])
        end
      end
    end
  end
end
