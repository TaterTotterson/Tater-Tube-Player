# Install Tater Tube Player on Steam Deck or Linux

Tater Tube Player is distributed directly through GitHub as a standalone Linux
desktop application. It does not require a storefront account, root access, or
administrator access.

## One-click Steam Deck installation

1. Switch the Steam Deck to **Desktop Mode**.
2. Download
   [Install-Tater-Tube-Player.desktop](https://github.com/TaterTotterson/Tater-Tube-Player/releases/latest/download/Install-Tater-Tube-Player.desktop).
3. Open the downloaded file and approve the execution prompt.
4. When installation completes, return to Gaming Mode and open
   **Library > Non-Steam > Tater Tube Player**.

The installer verifies the release checksum, installs entirely under the
current user’s home directory, creates a desktop application entry, and asks
SteamOS to add it as a non-Steam game. Pairing information and settings remain
outside the replaceable application directory and survive updates.

## Desktop Linux installation

The same installer works on 64-bit x86 desktop Linux. Open the downloaded
installer shortcut or run:

```bash
curl -fL -o /tmp/install-tater-tube-player.sh \
  https://github.com/TaterTotterson/Tater-Tube-Player/releases/latest/download/install-linux.sh
chmod +x /tmp/install-tater-tube-player.sh
/tmp/install-tater-tube-player.sh --no-add-to-steam
```

The application is added to the desktop’s Audio & Video menu. No `sudo`
command is required or supported.

## Updating

Run the same installer again. The previous application is kept until the new
archive has passed its checksum verification and is ready to replace it.
