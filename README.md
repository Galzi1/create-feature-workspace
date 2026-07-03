# create-feature-workspace
Scripts for creating feature workspaces (similarly to Cursor workspaces but tool-agnostic)

## Use them like so:

### Unix Operating Systems

```bash
./create-feature-workspace.sh \
  --feature-name feature-x \
  --config-file ./repos.ini \
  --workspaces-root ~/workspaces
```

### Windows Operating Systems (PowerShell)

```powershell
.\create-feature-workspace.ps1 `
  -FeatureName feature-x `
  -ConfigFile .\repos.ini `
  -WorkspacesRoot ~/workspaces
```