#!/bin/sh

# Install Bundler if not present
if ! command -v bundle > /dev/null; then
  echo "Installing Bundler..."
  gem install --user-install bundler
fi

# Set up local gem installation path
export GEM_HOME=$HOME/.gem
export PATH=$PATH:$GEM_HOME/bin

# Check if CocoaPods is installed, if not install using Bundler
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods via Bundler..."
  if [ ! -f Gemfile ]; then
    bundle init
    echo "gem 'cocoapods'" >> Gemfile
  fi
  bundle install --path vendor/bundle
fi

# Install pods
bundle exec pod install
