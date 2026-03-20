cask "duckbar" do
  version "0.2.0"
  sha256 "991b8e5f1ed4600303b9e6e2575ea281acc0e306f8f80347dd78b647b7a53bee"

  url "https://github.com/rofeels/duckbar/releases/download/v#{version}/DuckBar-#{version}.zip"
  name "DuckBar"
  desc "macOS menu bar app for monitoring Claude Code sessions"
  homepage "https://github.com/rofeels/duckbar"

  depends_on macos: ">= :sonoma"

  app "DuckBar.app"

  zap trash: [
    "~/Library/Preferences/com.munbbok.duckbar.plist",
  ]
end
