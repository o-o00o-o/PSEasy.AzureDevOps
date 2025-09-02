#Requires -Version 5
<#
.SYNOPSIS
    Produces a json compatible with ChildTasksTemplate from our DRY and simplified version

.NOTES

ONE TEMPLATE FOR EACH WORKITEM
------------------------------
due to the limitations of ChildTasksTemplate https://github.com/jpiquot/ChildTasksTemplate/issues/15
we need to produce one template for each workitem

so for an item "Dev Tasks" with 2 workItemTypes Bug and Product Backlog Item
we will produce two templates
    - Dev Tasks - Product Backlog Item
    - Dev Tasks - Bug

GET List of fields with full name
----------------------------------
Can use WIQL Playground https://xxxx.visualstudio.com/Vega/_apps/hub/ottostreifel.wiql-editor.wiql-playground-hub
or https://xxxx.visualstudio.com/_apis/wit/fields

.EXAMPLE

Get-AzureDevopsChildTasksJson -Path .\script\AzureDevopsChildTasks.json

#>
function Get-AzureDevopsChildTasksJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $Path

        # [Parameter()]
        # [switch]
        # $Passthru
    )

    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'
    try {
        $out = [PSCustomObject]@{
            version   = 2
            templates = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        # . "$PSScriptRoot\private\Get-WorkItemTemplateModel.ps1"
        $TemplateConfig = Get-WorkItemTemplateModel -Path $Path

        foreach ($template in $TemplateConfig.ToArray2()) {
            foreach ($parentWorkItemType in $template.parentWorkItemTypes) {
                $outTemplate = [PSCustomObject]@{
                    name  = "$($template.Name) - $($parentWorkItemType)"
                    tasks = [System.Collections.Generic.List[PSCustomObject]]::new()
                }

                foreach ($child in $template.items.ToArray2()) {
                    # only if is for the same parentWorkItemType (or there isn't one for this child)
                    $doThisWorkItemType = (-not $child.PSObject.Properties['parentWorkItemTypes'] -or
                        (
                            $child.PSObject.Properties['parentWorkItemTypes'] -and
                            $child.parentWorkItemTypes -eq $parentWorkItemType
                        ))

                    $childNotDisabled = -not ($child.PSObject.Properties['disabled'] -and $child.disabled)

                    # right now only tasks are supported by ChildTasksTemplate although we define others in our master json (in hope!)
                    $childIsTask = (-not $child.PSObject.Properties['workItemType'] -or (
                            $child.PSObject.Properties['workItemType'] -eq 'Task'
                        ))

                    if ($doThisWorkItemType -and $childNotDisabled -and $childIsTask
                    ) {
                        $taskName = "* $($child.Name)$(if ($child.PSObject.Properties['when']){" [$($child.when)]"}else{''})"

                        $outTask = [PSCustomObject]@{
                            name   = $taskName
                            fields = [System.Collections.Generic.List[PSCustomObject]]::new()
                        }

                        # Add the title which is inferred
                        $outTask.fields.Add([PSCustomObject]@{
                                name  = 'System.Title'
                                value = $taskName
                            })

                        foreach ($field in $child.fields.ToArray2()) {
                            $fieldValue = $field.Value

                            ## assigned to doesn't work right now so remove it this is due to a bug https://github.com/jpiquot/ChildTasksTemplate/issues/16, need to clear this for now
                            if ($fieldValue -eq '{System.AssignedTo}' -and $field.Name -eq 'System.AssignedTo') {
                                $fieldValue = ''
                            }

                            ## it seems that it doesn't like empty values, so ignore them
                            if ($fieldValue -ne '') {
                                $outTask.fields.Add([PSCustomObject]@{
                                        name  = $field.Name
                                        value = $fieldValue
                                    }
                                )
                            }
                        }
                        $outTemplate.tasks.Add($outTask)
                    } # else skip
                }
                $out.templates.Add($outTemplate)
            }
        }

        # if ($Passthru) {
        #     return $out
        # } else {
        $out | ConvertTo-Json -Depth 10 | Set-Clipboard
        Write-Information "The Json has been written to the clipboard. Paste it in the browser that has just been opened (switch it from tree to text first)" -InformationAction Continue
        Start-Process "https://xxx.visualstudio.com/yyy/_settings/Fiveforty.ChildTasksTemplate.child-tasks-template-settings"
        # }
    }
    catch {
        throw
    }
}
