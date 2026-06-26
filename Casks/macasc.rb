cask "macasc" do
  version "1.0.0"
  sha256 "434d04be5b956048846a53c7e2eb41dd0f060bb7d8c8eeaefd519b34705f9576"

  url "https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg"
  name "Mac ASC"
  desc "Menu bar storage analyzer and custom terminal shortcuts utility"
  homepage "https://github.com/Rian445/MacAsc"

  app "Mac ASC.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/Mac ASC.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.rian445.MacASC.plist",
  ]
end
