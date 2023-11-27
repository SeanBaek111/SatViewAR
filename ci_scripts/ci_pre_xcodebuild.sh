#!/bin/sh

# Check if CocoaPods is installed
if ! command -v pod > /dev/null; then
  echo "Installing CocoaPods..."
  gem install cocoapods
fi

# Install pods
pod install
