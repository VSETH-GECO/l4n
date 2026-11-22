# Payrexx can't work without its API key. Not checked:
# - in tests, where the Payrexx API is stubbed and test_helper.rb sets a dummy
#   key (tasks like db:create in CI boot the app without test_helper.rb)
# - while building the Docker image, where the assets are precompiled without secrets
Figaro.require_keys(%w[payrexx_api_key]) unless Rails.env.test? || ENV['BUILDING_DOCKER_IMAGE'] == 'true'
