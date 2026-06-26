cask "macasc" do
  version "1.0.0"
  sha256 "d71cbd705191bd931d17f3b0436e6fd5438d6861705bf10e1dc5fd3d58bae3b7"

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
