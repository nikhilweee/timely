cask "timely" do
  version "0.3.0"
  sha256 "ca45d18a5239b1477158be7f5742f15e28b9ed02bc317ba264323d1ab9d1a814"

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
