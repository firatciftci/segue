cask "segue" do
  version :latest
  sha256 :no_check

  url "https://github.com/firatciftci/segue/releases/latest/download/Segue.dmg"
  name "Segue"
  desc "Switch keyboard input sources with shortcuts, modifier keys, and app rules"
  homepage "https://github.com/firatciftci/segue"

  auto_updates true

  app "Segue.app"
  binary "#{appdir}/Segue.app/Contents/Helpers/segue"

  uninstall quit: "com.firatciftci.Segue"

  zap trash: [
    "~/Library/Caches/com.firatciftci.Segue",
    "~/Library/HTTPStorages/com.firatciftci.Segue",
    "~/Library/Preferences/com.firatciftci.Segue.plist",
  ]
end
