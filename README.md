# Earth Backgrounds

> A minimal macOS menu bar app that sets stunning Google Earth View satellite images as your desktop wallpaper — automatically.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)
![License](https://img.shields.io/github/license/sonithch/earth-backgrounds)
![Release](https://img.shields.io/github/v/release/sonithch/earth-backgrounds)

---

## Features

- **Random wallpaper** — fetches a beautiful satellite image from Google Earth View with one click
- **Auto-refresh** — change your wallpaper every 15 min, 30 min, 1 hour, 3 hours, 6 hours, or daily
- **Image info** — see the location name, region, coordinates, and a direct link to Google Maps
- **Launch at login** — starts silently in the menu bar when you log in
- **Local cache** — keeps the last 10 images on disk so changes are instant on repeat

---

## Download

**[→ Download latest release](https://github.com/sonithch/earth-backgrounds/releases/latest)**

1. Open the `.dmg`
2. Drag **Earth Backgrounds** into the **Applications** folder
3. Eject the disk image and launch the app — the globe icon appears in your menu bar

> **First launch:** macOS may warn that the app isn't notarized.
> Right-click the app → **Open** → **Open** to approve it once.

**Requires macOS 13 Ventura or later.**

---

## Build from source

```bash
git clone https://github.com/sonithch/earth-backgrounds.git
cd earth-backgrounds
open earth-backgrounds.xcodeproj
```

Press **⌘R** in Xcode to build and run.

---

## License

MIT — see [LICENSE](LICENSE).
