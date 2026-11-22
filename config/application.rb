require_relative 'boot'
require_relative 'version'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module L4n
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Keep backwards compatibility for now. We probably will need to update this to SHA256 and make an upgrade migration
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1

    # Load the secret key base from figaro if they're not present yet
    credentials.secret_key_base ||= Figaro.env.secret_key_base

    # Time tone
    config.time_zone = 'Bern'

    # We don't want remote forms for now (turbo does not work perfectly without it)
    config.form_with_generates_remote_forms = false

    # ActiveRecord encryption
    config.active_record.encryption.primary_key = Figaro.env.ar_primary_key
    config.active_record.encryption.deterministic_key = Figaro.env.ar_deterministic_key
    config.active_record.encryption.key_derivation_salt = Figaro.env.ar_key_derivation_salt

    # Serve SVGs with their real content type so they render in <img> tags
    # (e.g. footer logos). They are still served with "Content-Disposition:
    # attachment" since they are not in `content_types_allowed_inline`, so
    # opening a blob URL directly downloads it instead of executing scripts in
    # it on our origin.
    config.active_storage.content_types_to_serve_as_binary -= ['image/svg+xml']

    # Array holding the payment gateways
    config.payment_gateways = []

    # Override layouts for Doorkeeper
    config.to_prepare do
      # Only Authorized Applications
      Doorkeeper::AuthorizedApplicationsController.layout 'application'

      # Only Authorization endpoint
      Doorkeeper::AuthorizationsController.layout 'devise'
    end
  end
end
