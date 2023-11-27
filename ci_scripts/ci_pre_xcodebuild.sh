#!/bin/sh

# Check if CocoaPods is installed
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods..."
  gem install --user-install cocoapods
fi

# Add local gems to PATH
export PATH=$PATH:$(ruby -r rubygems -e 'puts Gem.user_dir')/bin

# Install pods
pod install
