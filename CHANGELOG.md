# Changelog

## Unreleased

## 2.4.2

- added custom brush color picking through the system color picker when `configuration.features.allowsColorPicker` is enabled
- added default borders to visible color swatches so light colors such as white remain distinguishable in inspector palettes

## 2.4.1

- collapsed the fullscreen bottom toolbar automatically when no primary tools remain after runtime filtering

## 2.4.0

- updated the floating Layers button to hide (and auto-dismiss the panel) when the canvas has fewer than 2 nodes
- updated the emoji picker to show keyboard-style categories with sticky section headers backed by `CanvasEmojiCatalog` and bundled `emoji-test.txt`
- updated inline image sources to encode transparent images as PNG (opaque images may use JPEG) and restricted inline editing to text nodes

## 2.3.1

- removed the insert picker selected-items footer since selection is already visible on each tile

## 2.3.0

- added embedded chrome controls so host apps can hide undo and redo via `configuration.features.enabledTools`
- added `configuration.features.showsEmbeddedLayersButton` so embedded hosts can hide the floating layers button without affecting fullscreen mode
- collapsed the embedded bottom toolbar automatically when no primary tools remain after runtime filtering
- expanded configuration and UIKit coverage for embedded chrome visibility and backward-compatible config decoding

## 2.2.0

- added `CanvasEditorPresentationMode`, `CanvasEditorExportOutput`, and `CanvasEditorExportError` so host apps can embed the editor runtime and trigger export programmatically
- added `CanvasEmbeddedEditorView` and `CanvasEmbeddedEditorHandle` for SwiftUI hosts that need an embedded editor surface without fullscreen navigation chrome
- unified fullscreen and programmatic export onto a shared export pipeline while keeping the existing fullscreen delegate flow intact
- refreshed the example app with independent embedded editor demos and a multi-item export flow that merges edited outputs into a single PDF file

## 2.1.0

- added `deletesNodeOnDelete` to masked image payloads so masked slots can either clear only their photo content or remove the entire node when deleted
- unified masked-slot delete behavior across the overlay `xmark` handle and toolbar delete action, while hiding delete affordances for empty persistent mask slots
- increased the masked-slot photo add affordance and made its `+` icon scale from the displayed template size so it stays visible on downscaled canvases
- refreshed the bundled `MaskedFrames` example template and expanded automated coverage for masked-slot delete semantics, backward compatibility, and plus-icon sizing

## 2.0.2

- added a close confirmation alert that appears only after the canvas has been edited, so accidental back-navigation does not discard active work without warning

## 2.0.1

- changed the bottom toolbar from a multi-row grid into a horizontally scrollable tool strip on compact screens

## 2.0.0

- added filter editing, shared signature tooling, and picker workflows to the editor runtime
- added masked frame templates and masked image slot editing support
- refreshed the example app to cover the new flows and mixed-state demos

## 1.0.2

- updated selection handles to rotate with the selected node without inheriting node scale, which removes the counter-rotation feel on rotated items
- made selection handle sizing adaptive to the displayed canvas size with built-in minimum and maximum touch-target clamps

## 1.0.1

- added `CanvasEditorHostingStyle.navigationStack` so SwiftUI hosts can push the editor through `NavigationStack` without showing duplicate navigation bars
- fixed rotated text height resizing so dragging the height handle follows the text node's local height axis correctly

## 1.0.0

- first stable release of `CanvasKit` with `CanvasKitCore`, `CanvasKitUIKit`, and `CanvasKitSwiftUI`
- stabilized runtime configuration for theme, icons, strings, layout, resources, and enabled tools
- bundled default templates and package docs for host-app integration
- fixed SwiftUI keyboard-safe-area shrinking so the editor layout remains stable during inline text editing

## 0.1.0

- split the repository into `CanvasKitCore`, `CanvasKitUIKit`, and `CanvasKitSwiftUI`
- moved default templates into SwiftPM resources
- added runtime-driven editor configuration for theme, icons, strings, layout, resources, and tool availability
- added template/resource loader helpers
- added package docs and example client sources
