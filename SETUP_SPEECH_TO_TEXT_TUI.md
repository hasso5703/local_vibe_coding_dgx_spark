# Whisper Voice-to-Text Interface (TUI)

Bash TUI script for voice-to-text transcription via a **self-hosted** `whisper.cpp` server. Audio is processed locally (or on your private network) and is never sent to a public cloud API.

<figure>
<img src="assets/image/whisper_tui.png" alt="Whisper TUI Interface" />
<figcaption>Whisper TUI Interface</figcaption>
</figure>

## Features

* **Interactive Recording**: Start/stop recording by pressing Space
* **Multilingual**: Language support (FR, EN, DE, ES, IT, TR, AUTO)
* **Translation**: Enables translation to English (optional)
* **Ready to use**: The result is automatically copied to the clipboard

## Requirements

| Dependency | Command |
| --- | --- |
| FFmpeg | `ffmpeg` |
| jq | `jq` |
| curl | `curl` |
| grep | `grep` |
| uname | `uname` |

## Controls

| Key | Action |
| --- | --- |
| Space | Record / Stop |
| L | Change language |
| T | Translate to EN |
| Q | Quit |

## Installation

```bash
chmod +x whisper_tui.sh
./whisper_tui.sh

```

## Configuration

**Server**: The script automatically configures itself for your system (macOS/Linux/Windows).

⚠️ **Modify the server**:

* Replace `100.114.54.60` with the IP of your **private** server (e.g., DGX Spark via Tailscale).
* Or use `localhost` if the `whisper.cpp` server is running on the **same machine**.
* Change port `8025` if your local server uses a different port when launched with `whisper.cpp`.

## Quick Access (Recommended)

For faster access, it is highly recommended to create an alias in your shell configuration (e.g., `.bashrc` or `.zshrc`). This allows you to launch the tool from anywhere by simply typing `s2t`.

Add the following line to your config file:

```bash
# Replace /path/to/ with the actual location of the script
alias s2t="/path/to/whisper_tui.sh"

```

Then, reload your configuration:

```bash
source ~/.zshrc  # or source ~/.bashrc

```

You can now start the tool instantly by typing:

```bash
s2t

```

## Dependencies

If missing, install them via:

```bash
# macOS
brew install ffmpeg jq

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg jq curl

```