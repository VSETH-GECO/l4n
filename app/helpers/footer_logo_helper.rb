module FooterLogoHelper
  # Renders a footer logo attachment. Raster images are resized through the
  # given variant. SVGs can't be transformed by ActiveStorage, so the original
  # is rendered and sized through CSS instead (see components/footer_logos).
  #
  # Returns nil for attachments that aren't stored yet, e.g. when a form is
  # re-rendered after a failed validation.
  def footer_logo_image_tag(attachment, variant, **options)
    return unless attachment.attached? && attachment.blob.persisted?

    if attachment.variable?
      image_tag attachment.variant(variant).processed, **options
    else
      image_tag attachment, **options, class: class_names(options[:class], "footer-logo-svg-#{variant}")
    end
  end
end
