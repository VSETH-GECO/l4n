require 'test_helper'

# SVGs must be served as image/svg+xml so they render in <img> tags, but only
# ever as attachment so they can't run scripts on our origin when opened
# directly. See config/application.rb.
class ActiveStorageSvgTest < ActionDispatch::IntegrationTest
  def test_svg_is_served_as_svg_attachment
    blob = ActiveStorage::Blob.create_and_upload!(
      io:           StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 2"/>'),
      filename:     'logo.svg',
      content_type: 'image/svg+xml'
    )

    get rails_blob_path(blob, only_path: true)
    follow_redirect!

    assert_response :success
    assert_equal 'image/svg+xml', response.media_type
    assert_match(/\Aattachment;/, response.headers['Content-Disposition'])
  end
end
