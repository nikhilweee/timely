cask "timely" do
  version "0.3.0"
  sha256 "0771c17bdaebbb828971c1a37e98111c5120f95bbbdee554c73f8f04fa33b6cd"

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
