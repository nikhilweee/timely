cask "timely" do
  version "0.1.0"
  sha256 "8995c2cd700c684c98d2abdf9daf36d6ca822d224da522b57f75192c61973dee"

  url "https://github.com/nikhilweee/timely/releases/download/v#{version}/Timely.zip"
  name "Timely"
  desc "Minimal menu bar timer"
  homepage "https://github.com/nikhilweee/timely"

  depends_on macos: :ventura

  app "Timely.app"

  zap trash: "~/Library/Preferences/com.nikhilweee.timely.plist"
end
