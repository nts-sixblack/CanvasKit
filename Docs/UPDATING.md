# Updating

## Package maintenance

- bump the package version with semantic versioning
- bump the minor version when you add new public schema or runtime API such as node/style flags
- re-run package tests
- run `swiftlint`
- verify bundled template JSON still decodes after schema changes
- verify any new theme/icon/string field gets a sensible default
- verify new schema fields decode to safe defaults when omitted from legacy JSON
- verify permanent text still fits correctly in live editing and export rendering when text layout rules change

## Releasing

1. Land changes on `main`.
2. Update version numbers in:
   - `CHANGELOG.md`
   - `README.md` (Current release)
   - `Sources/CanvasKitCore/Resources/PackageMetadata.json`
3. Run `swiftlint`.
4. Run `swift test`.
5. Commit with `Prepare release X.Y.Z`.
6. Tag and push:
   - `git tag X.Y.Z`
   - `git push origin main`
   - `git push origin X.Y.Z`

## Host app checklist

- re-resolve package dependencies
- review any new `CanvasEditorConfiguration` fields
- re-check custom fonts and custom asset bundles if you changed resource layout
- open the example client and compare theme overrides against your own integration
