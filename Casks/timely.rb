cask "timely" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/nikhilweee/timely/releases/download/v#{version}/Timely.zip"
  name "Timely"
  desc "Minimal menu bar timer"
  homepage "https://github.com/nikhilweee/timely"

  depends_on macos: :ventura

  app "Timely.app"

  zap trash: "~/Library/Preferences/com.nikhilweee.timely.plist"
end
