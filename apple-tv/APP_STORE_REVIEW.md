# Apple TV App Review Notes

## Local network and App Transport Security

Tater Tube Player is a client for a user-operated Tater Tube Server. Many home
servers are intentionally available only on a private LAN and are entered by
private IPv4 address, such as `http://192.168.1.20:8080`. Apple Transport
Security's local-network exception covers unqualified and `.local` hostnames,
but not private IP literals, so the app declares `NSAllowsArbitraryLoads`.

The exception is constrained in application code:

- Plain HTTP is accepted only for loopback, link-local, private IPv4, unique
  local IPv6, `.local`, or unqualified local hostnames.
- Any server outside the local network must use HTTPS.
- Pairing credentials and media requests remain scoped to the paired server.
- Authenticated URLSession redirects cannot change host or port and cannot
  downgrade from HTTPS to HTTP.

Suggested App Review explanation:

> Tater Tube Player connects to media servers operated by the user on their
> private home network. These servers may be addressed by a private IP and may
> not have a publicly trusted TLS certificate. The app limits unencrypted HTTP
> connections to private, loopback, and link-local network addresses; remote
> servers must use HTTPS.

## Review access

The app includes a fictional demo catalog for interface review without a
server. Add `--demo` to the scheme launch arguments when running a development
build. Before App Store submission, provide either review-server pairing
instructions or a review build/configuration that exposes the demo entry point
without a launch argument.
