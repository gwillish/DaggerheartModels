# Sharing and Hosting Content Packs

Distribute your .dhpack to other Encounter users.

## Overview

Once you have a `.dhpack` file, there are several ways to share it — from a quick
one-to-one AirDrop at the table to a publicly hosted URL that Encounter keeps up to
date automatically.

## Device-to-device sharing

These methods work immediately with no hosting required.

### AirDrop

The fastest option for sharing at the table. On the sending device, tap the `.dhpack`
file in Files and tap **Share → AirDrop**. Select the recipient's device. On the
receiving device, tap **Open in Encounter**.

Works between any combination of iPhone, iPad, and Mac running Encounter.

### Files app and iCloud Drive

Copy the `.dhpack` file to iCloud Drive (or any cloud storage you share with your
group). The recipient taps the file in Files and chooses **Open in Encounter**.

### Email and Messages

Attach the `.dhpack` file to an email or iMessage. The recipient taps the attachment
and opens it in Encounter. Most mail clients send the file as-is; some may warn about
unknown file types — this is safe to dismiss.

## URL-based sources

Encounter supports adding a `.dhpack` file by URL. Once added, the app stores the
pack locally and can refresh it on demand to pick up updates. This is the best option
for packs that are actively maintained and shared with a community.

### Adding a URL source

1. In Encounter, open **Settings → Content Sources**.
2. Tap **Add Source**.
3. Paste the URL to the `.dhpack` file and give the source a name.
4. Tap **Fetch** — Encounter downloads the pack and imports the content.

To update a URL source later, tap **Refresh** on the source row. Encounter sends a
conditional request (using ETag) so it only downloads the file if it has changed.

### What makes a good host URL

Any URL that serves the raw `.dhpack` file directly works. For best results:

- **Serve the file with standard HTTP caching headers** — `ETag` or
  `Last-Modified`. Encounter uses these to skip re-downloading unchanged packs.
- **Use a stable, version-pinned URL** — don't use a URL that always points to the
  latest file (e.g. a `main` branch raw URL) if you want users to stay on a
  specific version. See the GitHub Releases section below for a version-pinned
  approach.
- **HTTPS only** — plain HTTP is not permitted by App Transport Security.

## Hosting options

### GitHub Releases (recommended)

GitHub Releases are the most reliable option for versioned packs. Each release gets
a permanent, stable URL that never changes.

1. Create a GitHub repository for your pack (or use an existing one).
2. Go to **Releases → Draft a new release**.
3. Tag the release with a version (e.g. `v1.0`).
4. Attach your `.dhpack` file as a release asset.
5. Publish the release.

The asset URL follows this pattern:

```
https://github.com/<owner>/<repo>/releases/download/<tag>/<filename>.dhpack
```

This URL is permanent — it will never serve different content, even if you publish a
new release later. Users who want the update add the new release URL as a separate
source, or you can provide a jsDelivr URL (see below) that always resolves to the
latest release.

### jsDelivr CDN

[jsDelivr](https://www.jsdelivr.com/) can serve GitHub release assets from a CDN with
aggressive caching and high availability. The URL format is:

```
https://cdn.jsdelivr.net/gh/<owner>/<repo>@<tag>/<filename>.dhpack
```

jsDelivr also supports a `@latest` alias that always resolves to the most recent
GitHub release:

```
https://cdn.jsdelivr.net/gh/<owner>/<repo>@latest/<filename>.dhpack
```

> **Note:** Use `@latest` only if you want users to always get the newest version
> automatically. For a stable, opt-in update experience, use a version-pinned URL.

### GitHub Gist

A quick option for small packs with no repository setup required.

1. Go to [gist.github.com](https://gist.github.com) and create a new gist.
2. Paste your pack JSON and name the file with a `.dhpack` extension.
3. Click **Create public gist**.
4. On the gist page, click **Raw** to get the direct file URL.

Gist raw URLs look like:

```
https://gist.githubusercontent.com/<user>/<gist-id>/raw/<filename>.dhpack
```

> **Note:** The raw URL for a gist changes with every edit. To share a stable URL,
> pin to a specific revision by appending the commit hash to the URL.

### Static hosting (Netlify, Vercel, S3, etc.)

Any static file host that serves files over HTTPS works. Upload your `.dhpack` file
and share the direct file URL. For best results, configure the host to set
`Content-Type: application/json` and `ETag` response headers.

### Self-hosted server

If you run your own server, serve the `.dhpack` file as a static asset. Ensure the
server sends `ETag` or `Last-Modified` headers so Encounter can use conditional
requests to avoid re-downloading unchanged content.

## QR codes

A QR code pointing to a hosted pack URL is a convenient way to share a pack at the
game table — attendees can scan it with the camera app and open the URL directly in
Encounter.

Any QR code generator works. Encode the full HTTPS URL to the `.dhpack` file. On iOS,
the camera app recognizes QR codes and shows a notification to open the URL; if
Encounter is installed and the URL serves a `.dhpack`, the OS routes it to the app.

## Listing your pack

Once your pack is hosted, share the URL wherever your group or community hangs out:
Discord, Mastodon, Reddit, itch.io, or a dedicated blog post. Including the direct
`.dhpack` URL and a QR code in your post makes it easy for people to add the source
without copy-pasting.
