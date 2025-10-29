# syntax=docker/dockerfile:1
FROM ruby:3.2.0
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

WORKDIR /app
COPY Gemfile* .
RUN bundle install
COPY . .

EXPOSE 3000
# CMD ["rake", "tmp:pids:clear"]
CMD ["rails", "server", "-b", "0.0.0.0"]