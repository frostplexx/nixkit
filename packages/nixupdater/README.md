Small Menubar utility that checks for updates to your dotifles.

Requirements:

- Have the $NH_FLAKE environment variable set to your flake location


```
NixUpdater.app/Contents/MacOS/NixUpdater [options]
  -i, --interval <seconds>    Auto-check interval (default: 1800)
  -f, --flake <path>          Git repo path (overrides $NH_FLAKE)
  -c, --command <cmd>         Update command (default: jinx update)
  -h, --help                  Show this help
  -t, --terminal <name>       terminal  (default)
                              iterm
                              kitty
                              alacritty
                              ghostty
```

Examples:
Check every 5 minutes
`open NixUpdater.app --args --interval 300z`
Use a different repo path
`open NixUpdater.app --args --flake /Users/alice/other-dotfiles`
Use a custom update command
`open NixUpdater.app --args --command "nh os switch"`
Combine flags
`open NixUpdater.app --args -i 600 -f ~/dotfiles -c "nh os switch"`
The right-click menu also shows the current interval (e.g. Refresh every 30m) so you can confirm the flag took effect.
