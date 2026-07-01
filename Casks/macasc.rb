cask "macasc" do
  version "1.0.0"
  sha256 "e49a1c763404cc77a02a90d420ddfd1770c64421b6ff854a62f14a351d9887e9"

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
