Function Get-AdoWorkItem {
    [CmdletBinding()]
    param(
        # the account name xxx.visualstudio.com
        [string]$VstsAccount,
        [string]$ProjectName,
        [string]$User = "Personal Access Token",
        [SecureString]$Token,
        [Parameter(Mandatory)][int]$WorkItemId
    )
    # . "$PSScriptRoot\..\Invoke-AdoRestMethod.ps1"

    $restMethodArgs = @{
        VstsAccount = $vstsAccount
        ProjectName = $ProjectName
        User = $User
        PatToken = $Token
        RestMethod = 'Get'
        ApiUri = "wit/workitems/$WorkItemId"
        ApiVersion = "7.0"
        # UriParts = @{

        # }
        # Body = [PSCustomObject]@{query = $query } | ConvertTo-Json
    }

    $result = Invoke-AdoRestMethod @restMethodArgs

    # $result = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $headers -Body $body

    $result | Get-Member | Out-String | Write-Verbose

    Write-Output $result
}
