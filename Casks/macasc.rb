cask "macasc" do
  version "1.0.0"
  sha256 "9c4f6da8d4447df310710845dfe81b527f6f26b21d583d1bc9e850d2375f92d1"

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
