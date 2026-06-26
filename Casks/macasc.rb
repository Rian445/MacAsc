cask "macasc" do
  version "1.0.0"
  sha256 "a5a6e74f6c14f4913d128149864f6969502b358cc0f62a0287260dec785a9562"

  url "https://github.com/Rian445/MacStorageUtility/releases/download/APP/Mac%20ASC.dmg"
  name "Mac ASC"
  desc "Menu bar storage analyzer and custom terminal shortcuts utility"
  homepage "https://github.com/Rian445/MacStorageUtility"

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
