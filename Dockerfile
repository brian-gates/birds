FROM ruby:3.0-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs 4

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-p", "4567", "-b", "tcp://0.0.0.0"] 