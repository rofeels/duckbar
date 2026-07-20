cask "duckbar" do
  version "0.4.6"
  sha256 "7a1373cbfeb71e31386ffdd5d98ef43413bc1c6b76a9356dbf251e7c45b8b9bb"

  url "https://github.com/rofeels/duckbar/releases/download/v#{version}/DuckBar-#{version}.zip"
  name "DuckBar"
  desc "macOS menu bar app for monitoring Claude Code sessions"
  homepage "https://github.com/rofeels/duckbar"

  depends_on macos: :sonoma

  app "DuckBar.app"

  zap trash: [
    "~/Library/Preferences/com.munbbok.duckbar.plist",
  ]
end
