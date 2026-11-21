require 'test_helper'

class FooterLogoHelperTest < ActionView::TestCase
  PNG_1X1 = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
  SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 2"/>'.freeze

  def test_raster_image_uses_variant
    logo = FooterLogo.create!(file: upload('logo.png', 'image/png', PNG_1X1))

    html = footer_logo_image_tag(logo.file, :medium, class: 'ms-2')

    assert_includes html, '/representations/'
    assert_includes html, 'class="ms-2"'
  end

  def test_svg_is_rendered_unmodified_with_size_class
    logo = FooterLogo.create!(file: upload('logo.svg', 'image/svg+xml', SVG))

    html = footer_logo_image_tag(logo.file, :medium, class: 'ms-2')

    assert_includes html, '/blobs/'
    assert_includes html, 'class="ms-2 footer-logo-svg-medium"'
  end

  # A form re-rendered after a failed validation has an unsaved blob attached,
  # which can neither be transformed nor linked to.
  def test_unsaved_attachment_renders_nothing
    logo = FooterLogo.new(file: upload('logo.svg', 'image/svg+xml', SVG))

    assert_nil footer_logo_image_tag(logo.file, :thumb)
  end

  private

  def upload(filename, content_type, content)
    Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
  end
end
