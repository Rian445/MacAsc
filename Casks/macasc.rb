cask "macasc" do
  version "1.1.0"
  sha256 "b7c43132eaf252b51a99767331e31947159c8720f4de3ab7714631799e9858ce"

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
