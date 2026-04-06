cask "duckbar" do
  version "0.4.4"
  sha256 "9f5e268c72a8c88055b9b84704d63893c809ffa7213aa6731df0accd497c04b5"

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
