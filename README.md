# Little MJ 🎤

A pixel-art desktop pet for macOS. Little MJ lives in your menu bar, walks along the bottom of the screen, dances, drinks orange juice, and grows up through nine eras, from Little Mike to Invincible.

## First time on a new laptop

Little MJ only runs on a **Mac**.

### 1. Install Apple's developer tools (once)

Open **Terminal** (press ⌘ Space and type "Terminal"), then run:

```
xcode-select --install
```

Click **Install** in the window that pops up and wait for it to finish. This gives you `git` and the Swift compiler.

### 2. Sign in to GitHub (once)

This repo is private, so the laptop needs to be signed in to GitHub. The easiest way is the GitHub CLI:

```
brew install gh        # if you have Homebrew; otherwise download it from https://cli.github.com
gh auth login          # pick GitHub.com → HTTPS → log in with a web browser
```

### 3. Download Little MJ

```
git clone https://github.com/Marie-6/desktop_mj.git ~/DesktopMJ
```

### 4. Add the songs

The songs aren't in this repo. They stay offline. Copy the `songs` folder from the other Mac (AirDrop or a USB stick) into `~/DesktopMJ`, so you end up with `~/DesktopMJ/songs/`.

Little MJ works without them, but "Record a song in the studio" needs them.

### 5. Build and start him

```
cd ~/DesktopMJ
./build.sh
nohup ./DesktopMJ &
```

A 🎤 appears in the menu bar and he walks onto your screen. 🎉

If macOS says the app can't be opened, go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Getting updates

When there's a new version on GitHub:

```
cd ~/DesktopMJ
git pull
./build.sh
pkill -x DesktopMJ; nohup ./DesktopMJ &
```

## How to play

Click the **🎤** in the menu bar, or **right-click Little MJ**, to see everything he can do.

Can't find the 🎤? On MacBooks with a notch, a crowded menu bar hides it. Press **⌃ Control + ⌥ Option + M** from anywhere to open his menu where your mouse is, or run `~/DesktopMJ/DesktopMJ` again.


- **Give a drink**: 🍊 orange juice (his favourite), 🥤 Coca-Cola (it's okay), 🔵 Pepsi (he hates it)
- **🏠 Studio**: open the studio and **🎙 record a song** from his current era
  - Recording **Thriller** turns the studio into a moonlit graveyard, like the short film, with zombie hands, fog and lightning
- **Visit a friend**
- **Dance moves**: 🌙 Moonwalk, 🌀 Spin, 🧟 Zombie dance (Thriller era)
- **🚶 Come out and play** / **👀 Peek** from the left or right edge
- **💤 Nap time** / **☀️ Wake him up**
- **🙈 Hide for…** 1, 5 or 15 minutes, or 1 hour: he disappears without quitting and comes back on his own. To bring him back sooner, choose **👋 Come back now** in the 🎤 menu, press **⌃⌥M**, or run `~/DesktopMJ/DesktopMJ` again.
- **Walking style**: mix, facing forward, or sideways
- **Visiting style**: when he visits a friend, he faces you, turns sideways to face his friend, or mixes it up
- **Wardrobe**: switch outfits. Each era unlocks as he grows, plus extra tour outfits.
- **🚪 Closet**: sunglasses, hats, 🦇 bat buddy, 🎃 pumpkin bucket
- **Sound**: mute or unmute
- **Start over as little Mike…**: reset his progress
- **Say goodbye (quit)**

His progress is saved on each Mac separately, so on a new laptop he starts as Little Mike.

## Start automatically when you log in (optional)

Go to **System Settings → General → Login Items**, click **+**, and choose `~/DesktopMJ/DesktopMJ`.
