# Contributing to Segue

Thanks for helping out. Bug reports, small fixes, and well-scoped features are all welcome.

## Before you start

For anything bigger than a small fix, open an issue first so we can agree on the approach before you spend time on it. Segue is meant to feel like it shipped with macOS, so follow the [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) and use system controls and behavior wherever they exist.

## Set up

You need Xcode 27 and [Homebrew](https://brew.sh).

```sh
brew bundle
xcodegen generate
open Segue.xcodeproj
```

`project.yml` is the source of truth for the Xcode project. The generated `Segue.xcodeproj` isn't checked in, so put build settings, files, and capabilities in `project.yml` and run `xcodegen generate` again.

The project has two targets: the Segue app and the `segue` command-line tool. The tool ships inside the app in `Contents/Helpers`.

## Code style

- Swift 6 with complete concurrency checking. Types are main-actor isolated by default.
- swift-format handles layout and SwiftLint handles everything else. Both run in strict mode, and the build treats warnings as errors.
- Write `Array<Element>` instead of `[Element]`, and use a `for` loop instead of `reduce`.
- Let names and structure explain the code, and don't add comments to the source.
- User-facing text lives in `Segue/App/Strings.swift`, with translations in the string catalogs in `Segue/Resources`. Use American English. Write descriptions in sentence case and labels and buttons in title case, as macOS does.

Run all the checks with:

```sh
tools/check.sh
```

The script formats the code in place, so commit any changes it makes.

## Pull requests

- Keep each pull request to one change.
- Start the title with a [Conventional Commits](https://www.conventionalcommits.org) type, like `feat: add a modifier gesture` or `fix(indicator): keep the label in view`. Pull requests are squash-merged, so the title becomes the commit message and the release note.
- For visible changes, include a screenshot or a short recording in both light and dark mode. Launching with `-demo` shows sample settings instead of your own.
- CI must pass before a pull request can merge.

## Releases

Maintainers cut a release by raising `MARKETING_VERSION` in `project.yml`, merging that change, and pushing a matching `v` tag, like `v1.2.0`. The release workflow builds, signs, and notarizes the app, publishes the DMG, and updates the Sparkle feed that installed copies check for updates.
