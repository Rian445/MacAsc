cask "macasc" do
  version "1.0.0"
  sha256 "7028152557beae389515c7f7933b6801ac2ccc1181f76ff2e648a34fcc04fca8"

  url "https://github.com/Rian445/MacAsc/releases/download/APP/Mac_ASC.dmg"
  name "Mac ASC"
  desc "Menu bar storage analyzer and custom terminal shortcuts utility"
  homepage "https://github.com/Rian445/MacAsc"

  depends_on :macos

  app "Mac ASC.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/Mac ASC.app"],
                   sudo: false
  end

  zap trash: "~/Library/Preferences/com.rian445.MacASC.plist"
end
