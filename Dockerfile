# Use ruby image to build our own image
FROM ruby:3.3.0

# Install dependencies
RUN apt-get update -qq && apt-get install -y postgresql-client libvips cron && apt update -y \
                       && curl -sSL https://deb.nodesource.com/setup_18.x | bash - \
                       && curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
                       && echo 'deb https://dl.yarnpkg.com/debian/ stable main' | tee /etc/apt/sources.list.d/yarn.list \
                       && apt-get update && apt-get install -y --no-install-recommends nodejs yarn supervisor dumb-init rclone && \
                       rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
                       chmod gu+s /usr/sbin/cron && \
                       groupadd --system --gid 1000 rails && \
                       useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash -d /app && \
                       chown rails /run

COPY docker/supervisord.conf /etc/supervisor/supervisord.conf

USER 1000:1000

# Create work dir
WORKDIR /app

# Set build-time variables
ARG RAILS_ENV=production
ARG BUILDING_DOCKER_IMAGE=true

# This value is only set such that the asset precompile works. It
# will not be available to the final container and you need to
# set the value in your docker compose
ARG SECRET_KEY_BASE=583364b0aaaef81adc0d476c18efec0c

# Install gems, skipping the test and development gems
## Copy gemfiles
COPY --chown=rails:rails Gemfile /app/Gemfile
COPY --chown=rails:rails Gemfile.lock /app/Gemfile.lock
## Copy payment gateways
COPY --chown=rails:rails payment_gateways/ /app/payment_gateways/
## Run bundle
RUN bundle config set --local without 'test development'
RUN bundle install

# Install yarn packages
COPY --chown=rails:rails package.json /app/package.json
COPY --chown=rails:rails yarn.lock /app/yarn.lock
RUN yarn install

# Add env var to enable YJIT
ENV RUBY_YJIT_ENABLE true

# Copy rails code
ADD  --chown=rails:rails . /app

# Precompile assets
RUN bundle exec rake assets:precompile && mkdir -p /app/.config/rclone

EXPOSE 3000

CMD ["/app/docker/start.sh"]
