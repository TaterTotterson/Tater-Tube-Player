# Tater Tube Player privacy policy

Effective September 7, 2026

Tater Tube Player is a local client for a Tater Tube Server chosen and operated
by the user. The Player does not require a Tater account, does not contain
analytics or advertising telemetry, and does not send a user's media catalog,
viewing activity, or pairing credential to Tater.

## Data handled by the Player

To remain paired, the Player stores the server address, player name, and
server-issued player token in the current operating-system user's settings. On
Linux, that settings file is restricted to the current user. The Player also
caches artwork, catalog responses, and viewing state locally so its interface
can load quickly.

The Player sends the pairing token, playback capabilities, catalog requests,
and viewing progress directly to the Tater Tube Server selected by the user.
It does not forward that credential when a network response redirects to a
different URL.

Optional Tater Picks content is requested through the user's own Tater Tube
Server and is available only when the server owner has separately configured
Tater Link. The Player itself does not communicate directly with a generative
AI provider.

## User-provided media

Tater Tube Player does not upload or redistribute the user's media. Playback
and artwork are requested from the user's Tater Tube Server. The server owner
controls that server, its media, its logs, and any external metadata or Tater
Link services configured there.

## Steam

When the Player is installed through Steam, Valve may process account,
installation, device, and usage information under Valve's own privacy policy.
Tater Tube Player does not use the Steamworks API for analytics or account
identification in its first release.

## Removing local data

The user can choose **Forget server** in the Player to remove its saved pairing
information and content cache. Any remaining operating-system application data
can be removed manually after uninstalling the Player.

## Questions

Privacy and support questions may be filed through the public Tater Tube Player
issue tracker:

https://github.com/TaterTotterson/Tater-Tube-Player/issues
