# Steam generative-AI disclosure

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

For live-generated content types, select only `Text` and `Voice`. Do not select
Code, Textures, 3D Models, Sound Effects, Music, or Other.

### Copyright safeguards

Suggested disclosure:

> Users cannot enter free-form prompts or request arbitrary generated content. The system performs one fixed recommendation task and may select only exact identifiers from the catalog supplied by the user's Tater Tube Server. Unknown or invented identifiers, duplicate selections, malformed responses, empty batches, and items outside the supplied catalog are rejected. Text length and recommendation-count limits prevent long-form reproduction. The feature generates only short recommendation commentary and optional speech of that same text; it does not reproduce or generate movies, television programs, artwork, music, or other media. We do not rely on any service claiming copyright indemnification or protection.

### Moderation strategy

Suggested disclosure:

> Tater Tube Player does not provide an AI chat interface or accept user-authored prompts. Generation is restricted by a fixed system instruction to brief, friendly media recommendations using a bounded catalog and compact viewing context. Responses must use a defined JSON structure. The server validates every catalog identifier, rejects unknown and duplicate items, limits each batch to 12 recommendations, enforces strict text-length limits, and discards malformed or empty output. The Player cannot submit arbitrary text for speech; voice can only be created from a validated recommendation stored by the server. Users can dismiss recommendations, and the entire feature is optional and hidden unless separately configured.

Before submission, Tater Totterson AI LLC verifies that the production Tater
Core still enforces the catalog allowlist, structured response, length limits,
and invalid-output rejection described above.

## External services

Answer `Yes` because a user may configure an external AI provider even though
the Player itself communicates only with the user's Tater Tube Server.

- Name shown to players: `Tater Link — user-configured AI provider`
- Website shown to players: `https://github.com/TaterTotterson/Tater`

### How generated content reaches players

> Tater Picks is an optional feature available when the player is paired with a user-operated Tater Tube Server that has Tater Link configured. Tater generates short recommendation explanations and a recommendation briefing using the user's configured local AI model or external AI provider. The validated briefing may also be synthesized into voice. Tater Tube Player communicates only with the user's server and does not provide free-form AI prompting. The feature is hidden when Tater Link is not configured.

### Monetization

> None. Tater Tube Player is free and has no AI-related microtransactions, subscriptions, or paid DLC. The developer does not purchase or resell AI usage. Users may run the feature with a local AI model. If a user independently configures a paid external AI provider through Tater, any resulting cost is managed directly between that user and the selected provider.

## Store-page AI description

Suggested public description:

> Generative AI assisted with selected original visual assets used by Tater Tube Player, including mascot illustrations, fictional demo artwork, Discovery category art, and Tube TV channel logos. These assets were reviewed before inclusion and do not contain third-party movie or television artwork.
>
> During use, the optional Tater Picks feature can generate short recommendation explanations and a synthesized voice briefing based on titles in the user's own Tater Tube Server library and viewing history. Tater Picks requires the user to configure Tater Link separately, does not accept free-form prompts through the Player, and is hidden when not configured. It does not generate movies, television programs, music, or other playable media.

## Mature-content survey note

The application build contains no movies or television programs. It plays media
provided by the user through their own server, so the nature of user-supplied
content is outside the shipped application. Answer every Steamworks question
according to the actual final build and store assets.
