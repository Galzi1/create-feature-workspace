param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureName,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [string]$WorkspacesRoot = "~/workspaces"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Expand-UserPath {
    param([string]$PathValue)

    if ($PathValue -eq '~') {
        return $HOME
    }

    if ($PathValue.StartsWith('~/') -or $PathValue.StartsWith('~\')) {
        return Join-Path $HOME $PathValue.Substring(2)
    }

    return $PathValue
}

function Parse-IniFile {
    param([string]$PathValue)

    $sections = @()
    $current = $null

    foreach ($rawLine in Get-Content -LiteralPath $PathValue) {
        $line = $rawLine.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith(';') -or $line.StartsWith('#')) { continue }

        if ($line -match '^\[(.+)\]$') {
            if ($null -ne $current) {
                $sections += $current
            }
            $current = [ordered]@{
                Section = $matches[1]
                Name    = $null
                Path    = $null
                Branch  = $null
            }
            continue
        }

        if ($line -match '^(.*?)=(.*)$') {
            if ($null -eq $current) { continue }
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            switch ($key) {
                'name'   { $current.Name = $value }
                'path'   { $current.Path = $value }
                'branch' { $current.Branch = $value }
            }
        }
    }

    if ($null -ne $current) {
        $sections += $current
    }

    return $sections
}

if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "Config file not found: $ConfigFile"
}

$WorkspacesRoot = Expand-UserPath $WorkspacesRoot
$workspaceDir = Join-Path $WorkspacesRoot $FeatureName
New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null

$sections = Parse-IniFile -PathValue $ConfigFile
if ($sections.Count -eq 0) {
    throw 'No repository sections found in config file'
}

$repoCount = 0
foreach ($repo in $sections) {
    if ([string]::IsNullOrWhiteSpace($repo.Name)) {
        throw "Section [$($repo.Section)] is missing required key: name"
    }
    if ([string]::IsNullOrWhiteSpace($repo.Path)) {
        throw "Section [$($repo.Section)] is missing required key: path"
    }
    if ([string]::IsNullOrWhiteSpace($repo.Branch)) {
        throw "Section [$($repo.Section)] is missing required key: branch"
    }

    $repoPath = Expand-UserPath $repo.Path
    if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
        throw "Repository path does not exist for [$($repo.Section)]: $repoPath"
    }

    & git -C $repoPath rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Path is not a git repository for [$($repo.Section)]: $repoPath"
    }

    $destination = Join-Path $workspaceDir $repo.Name
    if (Test-Path -LiteralPath $destination) {
        throw "Destination already exists for [$($repo.Section)]: $destination"
    }

    Write-Host "Creating worktree for [$($repo.Section)] -> $destination (branch: $FeatureName, base: $($repo.Branch))"
    & git -C $repoPath worktree add -b $FeatureName $destination $repo.Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree add failed for [$($repo.Section)]"
    }

    $repoCount++
}

Write-Host ""
Write-Host "Workspace created: $workspaceDir"
Write-Host "Repositories added: $repoCount"
Write-Host "Next step: cd $workspaceDir ; claude"