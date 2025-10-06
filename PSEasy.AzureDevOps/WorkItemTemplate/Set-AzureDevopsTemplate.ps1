#Requires -Version 5
<#
.SYNOPSIS
    Refreshes all templates in the given project from the path to the given Teams
    This is done in a way that supports the 1-click child tasks

.DESCRIPTION
    Identifies scripts it owns by name ignoring the number to assure creation in correct order
    e.g. "Dev Tasks - XX - Ensure requirement is fully understood"
    If already exists will replace otherwise will create
    Will delete any names that don't exist

.NOTES

.EXAMPLE

Deploy everything to all teams (as configured)
.\script\AzureDevOps\WorkItemTemplates\Set-AzureDevopsTemplates.ps1

Deploy everything just for Vega team
.\script\AzureDevOps\WorkItemTemplates\Set-AzureDevopsTemplates.ps1 -Teams 'Vega'

Deploy just a single Template to Vega
.\script\AzureDevOps\WorkItemTemplates\Set-AzureDevopsTemplates.ps1 -Teams 'Vega' -TemplateName 'Feature Templates'



#>
function Set-AzureDevopsTemplate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VstsAccount,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [string]
        # will recursively load all templates in this folder
        $Path,

        [Parameter()]
        [string]
        # if you want to only load a single template, specify here
        $TemplateName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        # Execute for all teams in the array
        $Teams = @(),

        [Parameter()]
        [SecureString]
        # PAT Token to allow access to the Azure DevOps REST API. Must have Work Item Templates (Read & Write) permissions
        $PatToken
    )

    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'
    try {
        $RestCommon = @{
            VstsAccount = $VstsAccount
            ProjectName = $ProjectName
            ApiVersion  = '6.0-preview.1'
            Password    = $PatToken
        }
        $WhatifCommon = @{
            WhatIf = $WhatIfPreference
        }
        # . "$PSScriptRoot\private\Get-WorkItemTemplateModel.ps1"
        $TemplateConfig = Get-WorkItemTemplateModel -Path $Path
        #$templateConfig = Get-Content $Path | ConvertFrom-Json

        # add some fields
        foreach ($template in $TemplateConfig.ToArray2()) {
            $i = 0
            foreach ($item in $template.items.ToArray2()) {
                if ($template.PSObject.Properties['parentWorkItemTypes']) {
                    $Ordinal = [string]::Format("{0:00}", $i++)
                    $item | Add-Member TemplateItemName "$($template.Name) . $Ordinal . $($item.Name)"
                    if ($item.PSObject.Properties['parentWorkItemTypes']) { ## item overrides template
                        $item | Add-Member TemplateItemDescription "[$([string]::Join(',', $item.parentWorkItemTypes))]"
                    }
                    else {
                        $item | Add-Member TemplateItemDescription "[$([string]::Join(',', $template.parentWorkItemTypes))]"
                    }
                }
                else {
                    # if template doesn't have parentWorkItemTypes then we mark as ignored so that 1-click doesn't pick it up (in-place vs children type)
                    $item | Add-Member TemplateItemName "$($template.Name) . $($item.Name)"
                    $item | Add-Member TemplateItemDescription "[ignore] $($item.notes)"
                }
                $item.TemplateItemDescription += " <<AUTO>> GENERATED. See WorkItemTemplates in GIT"
            }
        }

        foreach ($team in $Teams) {
            # reset all previous id's to prevent linking across teams
            foreach ($template in $TemplateConfig.ToArray2()) {
                foreach ($item in $template.items.ToArray2()) {
                    if ($item.PSObject.Properties['currentTemplateId']) {
                        $item.PSObject.Properties.Remove('currentTemplateId')
                    }
                    if ($item.PSObject.Properties['currentTemplateName']) {
                        $item.PSObject.Properties.Remove('currentTemplateName')
                    }
                }
            }
            Write-Information "Getting current templates for Team $team from Azure Devops" -InformationAction Continue
            # get all templates for this team https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/templates/list?view=azure-devops-rest-6.0
            # (only consider those with <<auto>> in description)
            # $currentTemplatesOutput = Invoke-AzureDevopsRest -Team $team -Api 'wit/templates?api-version=6.0-preview.1' -Method GET @RestCommon -WhatIf:$false
            $currentTemplatesOutput = Invoke-AdoRestMethod -Team $team -ApiUri 'wit/templates' -RestMethod GET @RestCommon -WhatIf:$false
            if ($currentTemplatesOutput.Count -gt 0) {
                $currentTemplates = $currentTemplatesOutput.value | Where-Object { $_.description -like '*<<auto>>*' }

                # work out which ones we no longer need and remove
                foreach ($currentTemplate in $currentTemplates) {
                    Write-Verbose "Trying to find $($currentTemplate.name) in our templates (ignoring the ordinal part)"

                    $NamePartsArray = $currentTemplate.Name.Split(' . ')
                    $NameParts = [PSCustomObject]@{
                        Team     = $NamePartsArray[0]
                        Template = $NamePartsArray[1]
                        Ordinal  = "$(if ( $NamePartsArray[2] -match '^\d+$') {$NamePartsArray[2]} else {''})"
                        Item     = "$(if ( $NamePartsArray[2] -match '^\d+$') {$NamePartsArray[3]} else {$NamePartsArray[2]})"
                    }

                    $NameParts | Format-List | Out-String | Write-Debug
                    ## always consider delete unless TemplateName param given and it doesn't match the current from name parts
                    if (-not ($TemplateName -and $TemplateName -ne $NameParts.Template)) {
                        $found = $false
                        foreach ($template in $TemplateConfig.ToArray2()) {
                            foreach ($item in $template.items.ToArray2()) {
                                if ($NameParts.Template -eq $template.Name -and
                                    $NameParts.Item -eq $item.Name -and
                                    #$NameParts.Team -eq $team -and
                                    $team -in $template.forTeams -and
                                    -not ($item.PSObject.Properties['disabled'] -and $item.disabled) # not disabled
                                ) {
                                    Write-Verbose "Found $($currentTemplate.name)"
                                    # we force as we are now on a different team but reusing the same set of templates
                                    $item | Add-Member currentTemplateId $currentTemplate.id -force
                                    $item | Add-Member currentTemplateName $currentTemplate.name -force
                                    $found = $true
                                    break
                                }
                            }
                            if ($found) {
                                break
                            }
                        }
                        if (-not $found) {
                            $actionDescription = "Delete ""$($currentTemplate.Name)"" from Team $($team)"
                            Write-Verbose "Couldn't find $($currentTemplate.name) (ignoring the ordinal part) in team $($team)"
                            if ($PSCmdlet.ShouldProcess($actionDescription)) {
                                Write-Information $actionDescription -InformationAction Continue
                                # $restOutput = Invoke-AzureDevopsRest -Team $team -Method DELETE -Api "wit/templates/$($currentTemplate.id)?api-version=6.0-preview.1" @RestCommon @WhatIfCommon
                                $restOutput = Invoke-AdoRestMethod -Team $team -ApiUri "wit/templates/$($currentTemplate.id)" -RestMethod DELETE @RestCommon @WhatIfCommon
                                Write-Verbose $restOutput
                            }
                        }
                    }
                }
            }

            # Create or replace existing ones
            Write-Information "Getting current templates for Team $team from our config" -InformationAction Continue
            foreach ($template in $TemplateConfig.ToArray2()) {
                if (-not ($TemplateName -and $TemplateName -ne $template.Name)) {
                    # all templates or only the one given in params
                    if ($team -in $template.forTeams) {
                        foreach ($item in $template.items.ToArray2() | where-object { -not ($_.PSObject.Properties['disabled'] -and $_.disabled) }) {
                            $body = [PSCustomObject]@{
                                name             = "$Team . $($item.templateItemName)"
                                description      = $item.TemplateItemDescription
                                workItemTypeName = "$(if (-not $item.PSObject.Properties['workItemType']) {'Task'} else {$item.workItemType})"
                                fields           = [PSCustomObject]@{}
                            }

                            # add title if we don't have one explicitly
                            if (-not $item.fields.PSObject.Properties['System.Title'] ) {
                                $titlePrefix = ''
                                if ($template.PSObject.Properties['prefixItemTitlesWith']) {
                                    $titlePrefix = $template.prefixItemTitlesWith
                                }
                                $body.fields | Add-Member "System.Title" "$($titlePrefix)$($item.Name)"
                            }

                            $blankInheritFields = @('System.AssignedTo')

                            foreach ($field in $item.fields.PSObject.Properties | Select-Object name, value) {
                                $fieldValue = $field.Value
                                if ($fieldValue -ne "<<UNCHANGED>>") {
                                    # if explicitly said as unchanged, don't add (e.g. System.Title if we don't want to set/change it)
                                    if ($field.Name -in $blankInheritFields -and
                                        $fieldValue -eq "{$($field.Name)}"
                                    ) {
                                        # 1 click expects blank to assign the parent value ### actually not sure this is true so commented out this block
                                        $fieldValue = ''
                                    }

                                    if ($fieldValue.EndsWith('.html>>')) {
                                        $htmlFilename = Join-Path $Path "html\$($fieldValue.Replace('<<','').Replace('>>',''))"
                                        $fieldValue = [string](Get-Content -Path $htmlFilename -Raw)
                                        Write-Debug "fieldValue is type $($fieldValue.GetType())"
                                        $fieldValue | Format-List | Out-String | Write-Debug
                                    }
                                    $body.fields | Add-Member $field.Name $fieldValue
                                }
                            }

                            $body | Format-List | Out-String | Write-Debug
                            $body | convertTo-Json | Write-Debug

                            if ($item.PSObject.Properties['currentTemplateId']) {
                                # replace
                                if ($item.currentTemplateName -eq $body.name) {
                                    $actionDescription = "Re-set ""$($item.currentTemplateName)"" in team $($team)"

                                }
                                else {
                                    $actionDescription = "Replace ""$($item.currentTemplateName)"" with ""$($body.name)"" in team $($team)"
                                }
                                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                                    Write-Information $actionDescription -InformationAction Continue
                                    #$restOutput = Invoke-AzureDevopsRest -Team $team -Method PUT -Api "wit/templates/$($item.currentTemplateId)?api-version=6.0-preview.1" -Body $body @RestCommon @WhatIfCommon
                                    $restOutput = Invoke-AdoRestMethod -Team $team -ApiUri "wit/templates/$($item.currentTemplateId)" -RestMethod PUT -Body $body @RestCommon @WhatIfCommon
                                    $restOutput | Out-String | Write-Debug
                                }
                            }
                            else {
                                # create
                                $actionDescription = "Create ""$($body.name)"" in team $($team)"
                                if ($PSCmdlet.ShouldProcess($actionDescription)) {
                                    Write-Information $actionDescription -InformationAction Continue
                                    #$restOutput = Invoke-AzureDevopsRest -Team $team -Method POST -Api "wit/templates?api-version=6.0-preview.1" -Body $body @RestCommon @WhatIfCommon
                                    $restOutput = Invoke-AdoRestMethod -Team $team -ApiUri "wit/templates" -RestMethod POST -Body $body @RestCommon @WhatIfCommon
                                    $restOutput | Out-String | Write-Debug
                                }
                            }
                        }
                    }
                }
            }
        }

    }
    catch {
        throw
    }
}
