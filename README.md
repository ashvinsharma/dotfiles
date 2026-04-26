# dotfiles

Config files for shell, editor, terminal, and tools — everything needed to feel at home
on a new machine. Clone, bootstrap, stow, done.

> **Configs only — not apps.** Tools like Neovim, Ghostty, and mise need to be installed
> separately. This repo only puts their config files in the right place.

---

## How it works

**Symlinks** — Most configs are managed with [GNU Stow](https://www.gnu.org/software/stow/).
A symlink is a pointer: `~/.zshrc` looks like a normal file but reads from
`dotfiles/.zshrc` in this repo. Stow creates these automatically. Edit anywhere — both
`~` and git see the change.

**Copies** — Some tools don't support symlinks: they ignore them, overwrite them, or
crash. Those configs are kept as plain file copies. We call these *copy-managed* files.
Over time the live copy and the repo copy can drift apart. A pre-commit hook (configured
in `lefthook.yml`) detects this before every commit and prompts you to sync. You can also
run it manually with `make check`.

The list of copy-managed files is in `scripts/app-files`. When in doubt, start with a
symlink — if the app misbehaves, re-adopt with `make adopt-cp`.

**Repo layout** — Files map to `~` by path:

```
dotfiles/
  .zshrc                      -->  ~/.zshrc                        (symlink)
  .gitconfig                  -->  ~/.gitconfig                    (symlink)
  .config/
    mise/config.toml          -->  ~/.config/mise/config.toml      (symlink)
    zed/settings.json         -->  ~/.config/zed/settings.json     (symlink)
  .claude/
    settings.json             -->  ~/.claude/settings.json         (copy — Claude writes back)
```

---

## Quickstart

> **Prerequisites:** macOS: requires Homebrew (`brew`). Linux: requires apt, dnf, or
> pacman. Both require `curl` and `git`.

> Requires SSH key configured for GitHub. HTTPS alternative:
> `git clone https://github.com/ashvinsharma/dotfiles.git`

mise is a tool version manager — it installs and pins versions of dev tools like
lefthook, gitleaks, Go, Node, and more.

```bash
git clone git@github.com:ashvinsharma/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles
make bootstrap   # install stow + mise + all tools (run once on a new machine)
make stow        # link dotfiles, restore copy-managed files, install git hooks
```

> **The repo directory must be named `dotfiles`.** The Makefile passes this as the stow
> package name. `~/workspace/dotfiles`, `~/dotfiles`, `~/code/dotfiles` all work.
> `~/my-dots` does not.

**Verify it worked:**
```bash
ls -la ~/.zshrc        # should show a symlink pointing into this repo
ls -la ~/.gitconfig    # same
ls -la ~/.claude/settings.json   # should be a real file, not a symlink
```
Open a new terminal and confirm your shell loads correctly.

---

## Cheatsheet

```
make help       show all targets
make bootstrap  install stow + mise + all tools  (once per machine)
make stow       link dotfiles + restore copies + install hooks
make restow     unstow then re-stow  (use after adding/removing files)
make unstow     remove all managed symlinks from ~
make dry-run    preview what stow would change — no modifications made
make adopt      adopt a conflicting file (symlink mode)
make adopt-cp   adopt a conflicting file (copy mode — tool doesn't support symlinks)
make check      check copy-managed configs for drift
```

---

## Workflows

### Restore on a new machine
```bash
make bootstrap
make stow
```

### Bring an existing file from ~ into the repo

**"Adopt"** means: take an existing config file and bring it under version control here.
`make adopt` runs a dry-run first, shows you what it would do, and asks for confirmation.

> `make adopt` only detects a conflict when the file already exists in the repo at the
> matching path. For a file not yet in the repo, create a placeholder first:
> ```bash
> mkdir -p .config/sometool && touch .config/sometool/config.json
> make adopt
> ```

If the tool supports symlinks (most do):
```bash
make adopt
```
Stow moves the live file into the repo and symlinks it back to `~`.

If the tool doesn't support symlinks (it overwrites or ignores symlinked configs):
```bash
make adopt-cp
```
Copies the file into the repo and registers it as copy-managed — adds it to
`scripts/app-files` and `.stow-local-ignore` automatically.

### Create a new config file directly in the repo

Drop the file into the repo at its `~`-relative path, then run `make stow`.

If the tool doesn't support symlinks, use `make adopt-cp` — it handles registration
automatically.

If you want to understand what it does under the hood:
1. Add the path to `scripts/app-files`
2. Add the path to `.stow-local-ignore` with dots escaped — they are regex:
   ```
   \.config/sometool/config\.json
   ```
   `.stow-local-ignore` tells stow which files to skip entirely. Each line is a regex
   (not a glob). It replaces stow's built-in ignore list, which is why you'll see legacy
   entries like CVS and RCS — those are stow's defaults, re-listed here so they're not
   lost.

### After a `git pull`

Run `make stow` after any pull — it's safe to re-run. (Symlinked files don't need it
since they point directly into the repo, but copy-managed files need to be refreshed from
the updated repo copy.)

---

## Troubleshooting

### Stowed into the wrong directory

`make unstow` always targets `~`. If you ran raw `stow` from the wrong directory,
symlinks landed somewhere unintended and `make unstow` won't clean them up — it doesn't
know where. Fix manually:

```bash
# from the directory where you accidentally ran stow:
stow -D dotfiles   # -D means delete — removes symlinks stow created in its parent dir

# then restore:
make stow
```

### Conflict: "existing target is not owned by stow"

Stow refuses to create a symlink when something already exists at that path.

**If it's a manual symlink pointing to the right file:**
```bash
rm ~/.config/sometool/file.json   # safe — only removes the pointer, not the file
make stow
```

**If it's a real file**, use adopt:
```bash
make adopt      # symlink mode
make adopt-cp   # copy mode — for tools that don't support symlinks
```
