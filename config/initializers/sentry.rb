# Error tracking via Sentry or a Sentry-compatible server such as GlitchTip.

# Only run this in production
return unless Rails.env.production?

# Skip when building the docker image
return if Figaro.env.building_docker_image

# Skip when no DSN is configured
return if Figaro.env.sentry_dsn.blank?

Sentry.init do |config|
  config.dsn = Figaro.env.sentry_dsn
  config.release = L4N::VERSION
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.traces_sample_rate = Float(Figaro.env.sentry_traces_sample_rate.presence || 0.01)
  config.send_default_pii = false

  # Same noise filter as the exception notifier
  config.excluded_exceptions += [
    'ActionController::BadRequest',
    'ActionController::InvalidAuthenticityToken',
    'ActionDispatch::Http::MimeNegotiation::InvalidType',
    'ActionController::UnknownHttpMethod'
  ]
end
