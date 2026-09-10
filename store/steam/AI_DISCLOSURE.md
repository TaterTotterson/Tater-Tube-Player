# Steam generative-AI disclosure draft

Tater Tube Player should disclose both pre-generated and optional live-generated
AI content in the Steam Content Survey.

## Pre-generated content

Suggested disclosure:

> Generative tools assisted with some original Tater mascot illustrations,
> fictional demo-library artwork, discovery-category artwork, and channel-logo
> artwork included with the application and its store materials. These assets
> were created specifically for Tater Tube Player, reviewed by the developer,
> and do not intentionally depict real performers, existing entertainment
> properties, or third-party logos. The application does not include commercial
> movies or television programs.

Keep the generation prompts and final source assets in the project archive. Do
not add scraped entertainment artwork to the shipped demo library.

## Live-generated content

Suggested disclosure:

> When a user separately enables Tater Link on their own Tater Tube Server,
> Tater can generate short media recommendations and spoken recommendation
> summaries from that user's server catalog and viewing activity. The Player
> does not provide a free-form prompt. Generation is restricted to a fixed
> recommendation task, and only catalog item identifiers supplied by the user's
> server are accepted. Outputs use a structured schema, unknown or invented
> item identifiers are rejected, item counts and text lengths are limited, and
> invalid output is discarded. Tater Picks is optional and is hidden when Tater
> Link is not configured.

Before submission, Tater Totterson AI LLC verifies that the production Tater
Core still enforces the catalog allowlist, structured response, length limits,
and invalid-output rejection described above.

## Mature-content survey note

The application build contains no movies or television programs. It plays media
provided by the user through their own server, so the nature of user-supplied
content is outside the shipped application. Answer every Steamworks question
according to the actual final build and store assets.
