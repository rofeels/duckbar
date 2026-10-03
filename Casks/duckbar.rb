cask "duckbar" do
  version "0.4.7"
  sha256 "66db6eccc4db96abc14527daf10e6f83a77bcba1b0a7164500f31d7767520ed1"

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
