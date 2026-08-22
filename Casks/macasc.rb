cask "macasc" do
  version "1.1.0"
  sha256 "62a22d363d0f4e052ec52951229aa4d7cf4ef3d98953fe608fba3b33dd927998"

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
