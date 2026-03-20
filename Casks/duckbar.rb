cask "duckbar" do
  version "0.2.1"
  sha256 "b0197b5959226998e0a147673d025337df570de9e3c03bf90b3ffcac51ef549f"

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
