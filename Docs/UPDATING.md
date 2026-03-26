# Updating

## Package maintenance

- bump the package version with semantic versioning
- re-run package tests
- verify bundled template JSON still decodes after schema changes
- verify any new theme/icon/string field gets a sensible default

## Host app checklist

- re-resolve package dependencies
- review any new `CanvasEditorConfiguration` fields
- re-check custom fonts and custom asset bundles if you changed resource layout
- open the example client and compare theme overrides against your own integration
