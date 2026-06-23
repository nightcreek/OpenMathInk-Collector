# OpenMathInk Collector (MVP)

SwiftUI + PencilKit local dataset collector for math handwriting and LaTeX labels.

## MVP scope

- Local sample creation/editing/confirmation
- PencilKit handwriting capture
- LaTeX text input with lightweight math keyboard
- Placeholder preview renderer (`LatexRenderService` protocol reserved)
- Local file persistence (`JSON + PNG + .drawing`)
- Export confirmed samples as a shareable folder package

## Suggested Xcode setup

1. Create a new **iPadOS/macOS SwiftUI App** project named `OpenMathInk Collector`.
2. Add all files under this directory into the app target.
3. Ensure `PencilKit` capability is available for iPad target.
4. Run on iPad simulator/device for full handwriting flow.

## Current export format

`OpenMathInkDataset_YYYYMMDD_HHMMSS/`
- `manifest.json`
- `consent.json`
- `license.txt`
- `privacy_notice.txt`
- `samples/*.json`
- `samples/*.png`
- `samples/*.drawing`

> ZIP compression is intentionally left as a follow-up hook; current MVP exports the folder directly for ShareLink.
