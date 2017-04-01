FROM ruby:2.4.0

# app dependencies
RUN apt-get update -qq && apt-get install -y build-essential nodejs graphviz

ENV RAILS_ENV=development \
    APP_HOME=/usr/src/app

RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN gem install rake pqueue slop byebug ruby_deep_clone ruby-graphviz terminal-table

ADD . $APP_HOME
RUN bundle
