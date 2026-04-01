# Changelog

## Unreleased

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
