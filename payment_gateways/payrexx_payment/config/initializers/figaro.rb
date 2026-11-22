# Payrexx can't work without its API key. It isn't available (and not needed)
# while building the Docker image, where the assets are precompiled.
Figaro.require_keys(%w[payrexx_api_key]) unless ENV['BUILDING_DOCKER_IMAGE'] == 'true'
