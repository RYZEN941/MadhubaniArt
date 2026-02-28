# 🎨 Mithila Studio

> A digital canvas for Madhubani — the sacred folk art of Bihar, India.

Mithila Studio is an iPad app built with SwiftUI and PencilKit that lets you create authentic Madhubani paintings. Draw with Apple Pencil or your finger, place traditional motifs, fill regions with pigment-inspired colors, and learn about six centuries of living art history — all in one place.

Built for the **Apple Swift Student Challenge**.

---

## Features

### Canvas
- Full PencilKit drawing surface (4000 × 4000pt) with pinch-to-zoom and pan
- Pen tool with adjustable brush sizes (2pt, 4pt, 8pt, 14pt)
- Eraser tool with adjustable sizes
- **Straight-line snap** and **circle snap** — draw a rough line or circle and it snaps to perfect geometry
- **Flood fill** — MS-Paint style BFS fill that respects ink boundaries; aborts on open/unbounded regions so it never floods the whole canvas accidentally
- Comprehensive **undo/redo** stack covering every action: strokes, eraser, fill, motif add/move/scale/rotate/delete, and clear-all

### Motifs
- 9 hand-crafted traditional motifs: Peacock, Lotus, Fish, Sun, Elephant, Twin Fish, Leaf, Border patterns
- Place, scale, rotate, and reposition motifs freely on the canvas
- **Per-region pixel fill** — tap any enclosed area inside a motif to fill just that region independently (like a coloring book), using BFS flood fill on the motif's own pixel buffer
- Fill regions accumulate — multiple regions can each have different colors
- Motif fill is undoable/redoable
- Duplicate, cut, copy, paste motifs
- Lock motifs to prevent accidental edits
- Layer panel to reorder, lock, or delete individual motifs

### Color Palette
- 12 traditional Madhubani pigment colors arranged as a circular palette wheel
- Tap the **center circle** (your current color) to open the native iOS color well — pick any color from the system spectrum, grid, or sliders
- Color choice automatically switches back to pen/fill mode

### Learn
Six illustrated cards covering the main schools and styles of Madhubani:

| Card | Topic |
|---|---|
| History | Origins in the 1934 Bihar earthquake; GI-tagged heritage |
| Kachni | Fine line work, hatching, stippling — no erasing |
| Bharni | Bold flat fills with vivid festival pigments |
| Godna | Tribal tattoo-inspired geometric dot patterns |
| Tantrik | Sacred geometry, yantras, fierce deity forms |
| Kohbar | Wedding art dense with fertility symbols |

Each card opens a detail modal with a description, cultural context, and art glimpses.

### Themes & Symbols
Ten thematic symbol cards — Mythology, Marriage, Nature, Fish, Lotus, Peacock, Sun & Moon, Bamboo, Turtle, Snake — each with a description of cultural significance in Mithila tradition.

### Save & Export
- Named save with conflict detection
- Thumbnail previews on the home screen show exactly what's on the canvas (cream paper background, motifs with rotation, all fill colors)
- **Export** as a full-resolution image via the system share sheet
- Projects persist across sessions using JSON + binary drawing data

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Drawing | PencilKit (`PKCanvasView`, `PKDrawing`, `PKStroke`) |
| Fill | Custom BFS flood fill on `CGContext` pixel buffers |
| Persistence | `Codable` + `FileManager` (JSON for metadata, binary for drawings) |
| Image export | `UIGraphicsImageRenderer` with CGContext transform for rotation |
| Platform | iPadOS 16+ |
| Language | Swift 5.9 |

---

## Architecture

```
MadhubaniArt.swiftpm
├── MyApp.swift              — App entry point
├── HomeView.swift           — Home screen: projects, learn, themes
├── CanvasView.swift         — Main drawing canvas + all tool logic
├── DrawingCanvas.swift      — UIViewRepresentable wrapping PKCanvasView + snap logic
├── ProjectStore.swift       — Persistence layer (save/load/delete projects)
├── OnboardingView.swift     — First-launch onboarding
├── MotifGallery.swift       — Motif tray grid
├── Colors.swift             — Color extensions (mithilaGold, handmadePaper, pigments)
└── Assets.xcassets          — Motif images, learn card images, theme glimpses
```

### Key Design Decisions

**Flood Fill via pixel BFS, not vector** — PencilKit strokes have no topology, so true region fill requires rendering to a pixel buffer and running BFS from the tap point. The canvas fill renders strokes at 1× scale, runs BFS with a 500k pixel cap (open boundary → abort), then converts the result back to scanline `PKStroke` objects so it lives in the PencilKit drawing and is fully undoable.

**Motif fill on a separate pixel buffer** — Each motif has its own `filledImageData: Data?` (a PNG of the motif with filled regions). BFS runs on the motif's pixel buffer rather than the canvas, so filling a peacock's eye doesn't affect anything outside the motif frame. Multiple taps accumulate — each new fill starts from the existing `filledImageData`, preserving previous fills.

**Undo stack with typed cases** — Rather than using `UndoManager`, the app maintains its own `[UndoItem]` stack with explicit `before`/`after` payloads for every mutation type. This makes undo/redo symmetrical and easy to reason about, and means the same `applyUndo(_:isUndo:)` function handles both directions.

**Drag delta, not absolute position** — Motif drag stores the position at gesture start and applies `Δx/Δy` from `DragGesture.translation`. This means every motif — old or newly placed — moves correctly regardless of where it was placed or what coordinate space the gesture reports.

---

## Running Locally

1. Clone the repo
2. Open `MadhubaniArt.swiftpm` in **Swift Playgrounds 4.4+** on iPad, or in **Xcode 15+** on Mac
3. Select an iPad simulator or a connected iPad
4. Build and run — no additional dependencies or configuration needed

> Apple Pencil is recommended for the best drawing experience, but finger input works too.

---

## Screenshots


![WhatsApp Image 2026-02-27 at 6 17 46 PM](https://github.com/user-attachments/assets/d5487160-9d94-4c71-a093-4a95f2cff2a9)

![WhatsApp Image 2026-02-27 at 6 22 50 PM](https://github.com/user-attachments/assets/4f330f49-35f5-438c-968f-53ba3efbe19b)

---

## Acknowledgements

The motif designs are inspired by traditional Madhubani line art from the Mithila region of Bihar, India — an art form practiced primarily by women for centuries on mud walls, floors, and handmade paper. This app is a respectful digital interpretation, not a reproduction.

---

## License

MIT — see [LICENSE](LICENSE) for details.
