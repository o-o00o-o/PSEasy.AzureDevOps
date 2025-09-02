Function Select-AdoWorkItem {
    [CmdletBinding()]
    param(
        # the account name xxx.visualstudio.com
        [string]$VstsAccount,
        [string]$ProjectName,
        [string]$User = "Personal Access Token",
        [SecureString]$Token,
        [string]$Query
    )
    # . "$PSScriptRoot\..\Invoke-AdoRestMethod.ps1"

    $restMethodArgs = @{
        VstsAccount = $vstsAccount
        ProjectName = $ProjectName
        User = $User
        PatToken = $Token
        RestMethod = 'Post'
        ApiUri = 'wit/wiql'
        ApiVersion = 1.0
        Body = [PSCustomObject]@{query = $query } | ConvertTo-Json
    }

    $result = Invoke-AdoRestMethod @restMethodArgs

    # $result = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Headers $headers -Body $body

    $result | Get-Member | Out-String | Write-Verbose

    Write-Output $result
}
