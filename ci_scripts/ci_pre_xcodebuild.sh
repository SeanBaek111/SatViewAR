#!/bin/sh

# Install Bundler if not present
if ! command -v bundle > /dev/null; then
  echo "Installing Bundler..."
  gem install --user-install bundler
fi

# Add local gems to PATH
export PATH=$PATH:$(ruby -r rubygems -e 'puts Gem.user_dir')/bin

# Check if CocoaPods is installed, if not install using Bundler
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods via Bundler..."
  bundle init
  echo "gem 'cocoapods'" >> Gemfile
  bundle install
fi

# Install pods
bundle exec pod install
