# My Ghostty Settings

## Setup

![Terminal](./docs/images/screenshot.png)

Run the one-time setup:

```sh
./setup.sh
```

Manual steps if you prefer:

```sh
./link_ghostty_config.sh
source /path/to/this/repo/shell_settings.sh
```

## Notes

- The prompt shows the current path, git branch, and async git diff stats.
- If the box-drawing glyphs don’t render, swap `╭`/`╰` in `shell_settings.sh` for ASCII.
