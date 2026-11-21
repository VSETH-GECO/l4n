# Development image: only the toolchain, the app source is bind-mounted.
# Used by docker-compose.dev.yml, not for production (see /Dockerfile).
FROM ruby:3.4.13

ARG UID=1000
ARG GID=1000

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends postgresql-client libvips \
 && curl -fsSL https://deb.nodesource.com/setup_26.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g yarn \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid ${GID} rails \
 && useradd --uid ${UID} --gid ${GID} --create-home --shell /bin/bash rails \
 # Pre-create mount points so the named volumes inherit the ownership
 && mkdir -p /app/node_modules \
 && chown -R rails:rails /app /usr/local/bundle

USER rails
WORKDIR /app

RUN gem install foreman

COPY --chown=rails:rails entrypoint.sh /usr/local/bin/dev-entrypoint
ENTRYPOINT ["dev-entrypoint"]
CMD ["bin/dev"]
