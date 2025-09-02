<#
.SYNOPSIS
    One-time installation for each developer workstation

.NOTES
    You should have already got the source code (GIT Repo)
#>
Push-Location $PSScriptRoot
try {
    git config core.hooksPath .githooks # ensure we are all using the same set of hooks
} finally {
    Pop-Location
}
