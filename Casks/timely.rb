cask "timely" do
  version "0.1.0"
  sha256 "8995c2cd700c684c98d2abdf9daf36d6ca822d224da522b57f75192c61973dee"

  url "https://github.com/nikhilweee/timely/releases/download/v#{version}/Timely.zip"
  name "Timely"
  desc "Minimal menu bar timer"
  homepage "https://github.com/nikhilweee/timely"

  depends_on macos: :ventura

  app "Timely.app"

  # The app is ad-hoc signed, so a quarantined first launch would hit the
  # Gatekeeper "could not verify" dialog. Strip just the quarantine flag
  # after install; the sha256 above still pins the download.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Timely.app"]
  end

  zap trash: "~/Library/Preferences/com.nikhilweee.timely.plist"
end
