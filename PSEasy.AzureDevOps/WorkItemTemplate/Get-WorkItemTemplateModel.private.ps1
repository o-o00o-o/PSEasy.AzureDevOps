<#
.SYNOPSIS
Gets the work item template model from the specified path.

.DESCRIPTION
A simple helper to traverse the path to build a PSCustomObject representation of the work item templates.

.PARAMETER Path
Path to the folder that contains the json definitions for the ADO templates

#>
function Get-WorkItemTemplateModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    # get all templates into a single structure
    $TemplateConfig = [PSCustomObject]@{}
    foreach ($jsonFile in Get-childItem -Path $Path -include '*.json*' -Recurse) {
        $TemplateConfig | Add-Member $jsonFile.BaseName (Get-Content $jsonFile | ConvertFrom-Json)
    }
    Write-Output $TemplateConfig
}
