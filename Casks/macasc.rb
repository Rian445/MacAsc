cask "macasc" do
  version "1.0.0"
  sha256 "05da56ad77122ef861cb36a3ae3e6138d53d8f64196c0a5f61df092a1dc9b381"

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
