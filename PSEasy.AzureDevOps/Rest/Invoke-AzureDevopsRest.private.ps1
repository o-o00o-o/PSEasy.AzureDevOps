<#
.SYNOPSIS
Calls Rest method for AzureDevops (Deprecated, use Invoke-AdoRestMethod instead, adding TeamName functionality)

.DESCRIPTION

.EXAMPLE
# Get context
$vct = gvct

# get all templates https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/templates/list?view=azure-devops-rest-6.0
$templates = Invoke-AzureDevopsRest -Token $vct.adoPatWorkItemRW -Api 'wit/templates?api-version=6.0-preview.1' -Method GET

.NOTES

In future it would be good to use autorest and swagger definitions to produce our powershell cmdlets from the REST API

https://devblogs.microsoft.com/powershell/cmdlets-via-autorest/
https://github.com/MicrosoftDocs/vsts-rest-api-specs/blob/master/specification/wit/6.1/workItemTracking.json
https://github.com/Azure/autorest

#>
Function Invoke-AzureDevopsRest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$VstsAccount,
        [string]$ProjectName,
        [string]$TeamName = $null,
        [string]$User = "Personal Access Token",
        [SecureString]$Token,
        [string]$Method,
        [string]$Api,
        [PSCustomObject]$Body = $null
    )
    try {
        # Base64-encodes the Personal Access Token (PAT) appropriately
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, ($Token | ConvertFrom-SecureString -AsPlainText))))

        # Construct the REST URL to obtain Build ID
        $uri = "https://$($vstsAccount)/$($projectName)/$(if ($TeamName) {"$($TeamName)/"} else {''})_apis/$($Api)"

        $body = $Body | ConvertTo-Json
        Write-Debug $body
        # Invoke the REST call and capture the results (notice this uses the PATCH method)
        if ($PSCmdlet.ShouldProcess("executing $Method on $uri")) {
            $result = Invoke-RestMethod -Uri $uri -Method $Method -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } -Body $body -verbose:$false

            Write-Output $result
        }
    } catch {
        throw
    }
}
