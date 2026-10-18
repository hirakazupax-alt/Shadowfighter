> Local illustrated build: see [MOONFALL_README.md](MOONFALL_README.md) for current controls, additions and verification.

# Shadow Fighters

A lightweight 2D arcade fighting game built with **LÖVE 11.5**.

We're building this as a **2-person team**, so this guide is designed to make it easy to get the game running and start making changes safely.

---

## 🎮 Current Game

Shadow Fighters currently has:

* Animated character-selection screen
* 4 fighters with unique health, speed, power, and jump stats
* Long side-scrolling campaign stage with a flag goal
* Multi-layer parallax scenery and level progress display
* Smash-style dynamic camera zoom that keeps both fighters visible
* Four cooldown-based super abilities for every fighter
* Working question blocks that release temporary Super Mushrooms
* Solid and moving platforms, pits, spikes, and alternate routes
* Six contested power-ups with distinct tactical effects
* Three-life checkpoint respawns and a trailing-player comeback boost
* 2D fighting
* Player vs Player
* CPU opponent
* Easy / Normal / Hard CPU difficulty
* High, mid, and low attacks with matching crouch and block behavior
* Posture-aware blocking
* Jumping
* Crouching
* Health and damage
* Knockback
* 60-second rounds
* Round scoring
* First-to-2 match system
* KO and timeout detection
* DRAW detection
* Match restart
* Rideable horse and boar with different speed and jump boosts
* Animal personalities, reactions, and character-specific bonds
* ~60 FPS on low-end hardware

The game is still being developed.

---

# 🖥️ Getting Started

## 1. Install LÖVE

You need **LÖVE 11.5** to run the game.

On Linux Mint/Ubuntu:

```bash
sudo apt update
sudo apt install love
```

Check that it installed:

```bash
love --version
```

You should see something similar to:

```text
LOVE 11.5
```

---

# 📥 2. Download the Project

If you are starting from scratch, clone the repository:

```bash
git clone https://github.com/Fightgamedev/Shadowfighter.git
```

Then enter the project:

```bash
cd Shadowfighter
```

---

# ▶️ 3. Run the Game

From inside the project folder:

```bash
love .
```

The game window should open.

Fight and ride across the scrolling Shadow Road. Reaching the red goal flag at
the far end wins the entire game. The progress bar under the timer shows how
close Player 1 is to the finish.

Jump into a **? block** from below to release a moving Super Mushroom. Either
fighter can collect it. For 14 seconds that fighter grows larger, gains longer
attack reach, deals 35% more damage, takes 20% less damage, and immediately
recovers 25 health. The red aura and HUD timer show who currently has the
advantage.

Other blocks contain shields, fireball power, speed boots, instant animal-bond
charms, and lightning that briefly stuns the opponent. Their colors and letter
icons identify them after they appear.

Each player starts with three lives. Knockouts and falling into pits cost one
life and respawn the fighter at the latest checkpoint with brief invulnerability.
The player who is behind in lives or far behind in the race receives a modest
speed and damage comeback bonus. Reaching the flag still wins immediately.

---

# 🎮 Controls

## Character Select

Use **A / D** to browse fighters and **J**, **Enter**, or **Space** to confirm.
In CPU mode, the opponent is selected randomly. Press **C** during a match to
return to character select.

## Player 1

| Key | Action        |
| --- | ------------- |
| A   | Move left     |
| D   | Move right    |
| W   | Jump          |
| S   | Crouch        |
| J   | High attack   |
| K   | Mid attack    |
| H   | Low attack    |
| L   | Block         |
| E   | Mount/dismount nearby animal |
| U   | Spider Web Sling |
| I   | Teleport          |
| O   | Spider Flight     |
| P   | Time Stop         |
| R   | Restart match |

## Player 2

When CPU mode is disabled:

| Key | Action     |
| --- | ---------- |
| ←   | Move left  |
| →   | Move right |
| ↑   | Jump       |
| ↓   | Crouch     |
| N   | High attack |
| M   | Mid attack  |
| ,   | Low attack  |
| B   | Block      |
| /   | Mount/dismount nearby animal |
| 1   | Spider Web Sling |
| 2   | Teleport          |
| 3   | Spider Flight     |
| 4   | Time Stop         |

High attacks are quick strikes that miss a grounded crouching opponent. Mid
attacks hit either stance. Low attacks strike the legs, pass through a standing
guard, and can be stopped by blocking while crouched. Hold **S + L** to crouch
block as Player 1; hold **↓ + B** as Player 2.

Spider Web Sling throws a web overhead and swings forward, damaging an opponent
it catches. Teleport shifts you behind a nearby opponent or forward when they
are far away, with a brief dodge window. Spider Flight lets you hover for three
seconds; use jump and crouch to rise and descend. Time Stop freezes the opponent
for three seconds. Each super has its own cooldown shown under the health bars.
The phone controller flashes, vibrates, and names the super when its button is
pressed.

The CPU will automatically mount an available nearby animal. The horse is
faster, while the boar gives a smaller speed and jump boost.

Unridden animals watch nearby fighters, approach characters they trust, flee
from incoming mounts, and interact when they meet. Every fighter has a favored
animal shown on the selection screen. Riding that animal creates a **Perfect
Bond**, adding extra movement, jump, and attack power.

---

# 🤖 CPU Mode

Fighter 2 is controlled by the CPU by default.

CPU settings are near the top of `main.lua`.

Look for:

```lua
cpuEnabled = true
```

To play against another human:

```lua
cpuEnabled = false
```

CPU difficulty:

```lua
cpuDifficulty = "normal"
```

Available difficulties:

```text
easy
normal
hard
```

---

# 🧑‍💻 Working on the Game

You do **not** need to understand the entire game before making changes.

Start small.

Good first changes include:

* Changing movement speed
* Changing damage
* Changing attack timing
* Changing CPU behavior
* Changing health
* Changing round time
* Improving visual effects

Before changing something, look at the existing code and try to understand what it does.

**Don't rewrite large sections unless necessary.**

---

# 🌿 Git Basics

We use Git to keep track of changes.

Think of it as a save system for the entire project.

## Check what changed

```bash
git status
```

## See your changes

```bash
git diff
```

---

# 🆕 Start a New Feature

**Do not normally work directly on `main`.**

Create a branch for your work:

```bash
git checkout -b my-feature
```

For example:

```bash
git checkout -b improve-cpu
```

Now you can safely work on your feature.

---

# 💾 Save Your Work

When you've made changes:

```bash
git add .
```

Then create a commit:

```bash
git commit -m "Improve CPU behavior"
```

A commit is basically a saved checkpoint.

---

# ☁️ Upload Your Work to GitHub

Push your branch:

```bash
git push -u origin my-feature
```

Replace `my-feature` with your actual branch name.

For example:

```bash
git push -u origin improve-cpu
```

---

# 🔀 Pull Requests

When your feature is finished:

1. Push your branch to GitHub.
2. Open the Shadowfighter repository on GitHub.
3. Create a **Pull Request**.
4. Explain what you changed.
5. Let the other developer review it.
6. Merge it into `main` when everything looks good.

This keeps the main version of the game safe.

---

# 🔄 Getting Someone Else's Changes

Before starting new work, update your local project.

First switch to main:

```bash
git checkout main
```

Then download the latest changes:

```bash
git pull
```

If you are starting a new feature afterward:

```bash
git checkout -b my-new-feature
```

---

# ⚠️ Important Git Rule

Before doing major work, make sure you know which branch you're on:

```bash
git branch
```

You should see something like:

```text
* my-feature
  main
```

The `*` shows your current branch.

**Avoid making experimental changes directly on `main`.**

---

# 🛑 If Something Goes Wrong

Don't panic.

**Do not randomly delete files or run commands you don't understand.**

First run:

```bash
git status
```

Then tell the other developer what happened.

Git usually gives us a way to recover.

---

# 🧪 Before Committing

Always test the game after making changes:

```bash
love .
```

Check that:

* The game launches.
* Fighters move.
* Attacks work.
* Health works.
* Rounds work.
* CPU works if your change affects the CPU.
* Nothing unrelated broke.

Then commit your changes.

---

# 📁 Important Files

Currently the project is intentionally very small.

```text
Shadowfighter/
│
├── conf.lua       # LÖVE game configuration
├── main.lua       # Main game code
├── README.md      # This guide
└── .gitignore     # Files Git should ignore
```

Most gameplay code is currently in:

```text
main.lua
```

As the project grows, we will eventually split the code into separate files.

---

# 🤝 Team Rules

### 1. Keep changes focused

Try not to mix unrelated changes together.

Bad:

```text
Improve CPU + redesign UI + add music + rewrite combat
```

Better:

```text
Improve CPU attack behavior
```

---

### 2. Test before committing

Don't commit something you haven't tested.

---

### 3. Write useful commit messages

Good:

```text
Improve CPU attack timing
```

```text
Add hit reaction animation
```

```text
Fix round timer
```

Bad:

```text
stuff
```

```text
update
```

```text
asdf
```

---

### 4. Communicate before changing major systems

If you want to completely rewrite something important, talk to the other developer first.

---

### 5. Don't be afraid to experiment

Use branches for experiments.

If something doesn't work, we can delete the branch without damaging `main`.

---

# 🛠️ Using Codex

Codex can help with development.

When asking Codex to modify the game:

1. Tell it exactly what you want.
2. Ask it to inspect the existing code first.
3. Make one feature at a time.
4. Test the game afterward.
5. Commit working changes.

Example:

```text
Add a simple hit-flash effect when a fighter takes damage.

Preserve all existing combat and round functionality.
Make the smallest change necessary.
Test that the game still launches at 60 FPS.
```

Avoid asking Codex to rebuild the entire game when only a small change is needed.

---

# 🚀 Project Goal

Build a fun, lightweight arcade fighting game that can run well on older hardware while gradually adding:

* More fighters
* Character selection
* Better animations
* Combos
* Special attacks
* Multiple arenas
* Sound effects
* Music
* Menus
* Controller support
* Better CPU AI

We'll add these systems one milestone at a time.

---

## 👊 Have Fun

This is a 2-person project.

Keep changes small, test often, communicate with each other, and don't be afraid to experiment.
