# Updating

## Package maintenance

- bump the package version with semantic versioning
- re-run package tests
- verify bundled template JSON still decodes after schema changes
- verify any new theme/icon/string field gets a sensible default

## Releasing

1. Land changes on `main`.
2. Update version numbers in:
   - `CHANGELOG.md`
   - `README.md` (Current release)
   - `Sources/CanvasKitCore/Resources/PackageMetadata.json`
3. Run `swift test`.
4. Commit with `Prepare release X.Y.Z`.
5. Tag and push:
   - `git tag X.Y.Z`
   - `git push origin main`
   - `git push origin X.Y.Z`

## Host app checklist

- re-resolve package dependencies
- review any new `CanvasEditorConfiguration` fields
- re-check custom fonts and custom asset bundles if you changed resource layout
- open the example client and compare theme overrides against your own integration
