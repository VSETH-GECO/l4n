# Payrexx can't work without its API key. Not checked:
# - in tests, where the Payrexx API is stubbed and test_helper.rb sets a dummy
#   key (tasks like db:create in CI boot the app without test_helper.rb)
# - while building the Docker image, where the assets are precompiled without secrets
#
# Don't use Figaro.require_keys here: it compares against ENV.keys case-sensitively,
# so it rejects PAYREXX_API_KEY. Figaro.env accepts both cases and rejects blank values.
skip_check = Rails.env.test? || ENV['BUILDING_DOCKER_IMAGE'] == 'true'
fail Figaro::MissingKeys, %w[PAYREXX_API_KEY] if !skip_check && Figaro.env.payrexx_api_key.blank?
