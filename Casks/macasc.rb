cask "macasc" do
  version "1.1.0"
  sha256 "effe12704412d46414ad6d43c7a3b21937a468fd0ec6923d50a0bdc22bed107d"

  url "https://github.com/Rian445/MacAsc/releases/download/v#{version}/Mac_ASC.dmg"
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
