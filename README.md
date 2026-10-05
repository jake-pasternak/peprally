# Peprally

An iOS app where people ask and answer questions about peptides, organised by peptide. Every peptide has its own topic. Anyone can ask. Clinicians and researchers who verify a credential get a badge on their answers, so you can tell who is answering.

**Live on the App Store as [Peprally+](https://apps.apple.com/app/id6760837248).**

I designed it in Figma, made the product decisions, and built it with Claude Code, which wrote most of the code. Every commit says so.

## Stack

- **Swift 5.9 and SwiftUI**, iOS 17. State lives in one `@Observable` `AppModel` passed through the environment.
- **Supabase** for the backend: Postgres, Row Level Security, triggers, and Auth.
- **Sign in with Apple**, exchanged for a Supabase session with `signInWithIdToken`.
- **XcodeGen**. `project.yml` is the source of truth and the `.xcodeproj` is generated, so the project file never conflicts.
- **XCTest** for the logic that turns database rows into what the screens show.

## How it's laid out

```
Peprally/               one file per screen (HomeView, ThreadView, ComposeView, ...)
  DesignSystem.swift    colour, type, spacing and motion tokens used everywhere
  Backend/              one service per table (FeedService, ReplyService, LikeService, ...)
  SampleData.swift      demo fixtures, compiled into the demo target only
PeprallyTests/          unit tests
supabase/migrations/    schema, triggers and access rules, in the order they were applied
```

The app has no navigation stack. `PeprallyApp` switches on one `AppStage` (`loading → welcome → setup → home`) and presents everything else as overlays.

## Running it

Built with Xcode 26. You also need XcodeGen (`brew install xcodegen`).

```sh
cp Peprally/Backend/SupabaseConfig.example.swift Peprally/Backend/SupabaseConfig.swift
xcodegen generate
open Peprally.xcodeproj
```

Then pick a scheme:

- **PeprallyDemo** runs with no backend and no account. It opens on a full feed of sample questions, threads, a profile and notifications. Start here. Every person, credential and post in it is made up.
- **Peprally** is the real app. It needs a Supabase project (below) and a signing team that has Sign in with Apple enabled.

Tests: `⌘U` on the Peprally scheme.

### Backend

1. Create a Supabase project and run `supabase link --project-ref <ref>`.
2. `supabase db push` applies everything in `supabase/migrations/` in order.
3. Run `supabase/seed.sql` in the SQL editor to create the peptide topics.
4. Turn on the Apple provider (Authentication → Providers) with the app's bundle id as the client id.
5. Put the project URL and publishable key in `SupabaseConfig.swift`.

## Data and security

Every table has Row Level Security on and denies by default. Content is public to read. You can only write as yourself, and moderators can edit or remove content.

RLS decides which rows you can touch, not which columns, so on top of it the client roles only get write access to the columns the app actually sends (`20261005120000_lock_privileged_columns.sql`). Without that, a user could set `is_moderator` or a verified credential on their own profile. Like and reply counts are kept by triggers that run as the table owner, so nobody can edit them from the client.

## Known limitations

These controls are in the interface but don't reach the backend yet:

- Reporting a post, and pinning one as a moderator
- Uploading a verification document, and the moderator application
- Polls, attachments and GIFs in the composer (the question itself posts; these are dropped)
- People and topic results in search (question search filters the live feed)
- The unread dot on the profile's Notifications tab
- Saving the peptides you follow (held in memory, so they reset on relaunch)
- Push notifications (in-app notifications work; nothing is delivered through APNs)
