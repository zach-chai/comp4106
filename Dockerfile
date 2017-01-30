FROM ruby:2.4.0

# app dependencies
RUN apt-get update -qq && apt-get install -y build-essential nodejs

ENV RAILS_ENV=development \
    APP_HOME=/usr/src/app

RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD . $APP_HOME
RUN bundle
RUN gem install byebug
