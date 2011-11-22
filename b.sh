#!/bin/bash -e
# Use the correct ruby
rvm use "ruby-1.9.2-p290@previewify"
# Do any setup
# e.g. possibly do 'rake db:migrate db:test:prepare' here
gem install bundler
bundle install
# Finally, run your tests
rake test
