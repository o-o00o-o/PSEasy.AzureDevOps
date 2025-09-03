<#<#
.SYNOPSIS
Helper to run ADO REST calls consistently for all our tools

.DESCRIPTION
https://learn.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-7.1

.EXAMPLE

1. List all PRs

$restMethodArgs = @{
    PatToken = (gvct -Environment 'None').adoPatWorkItemRW
    RestMethod = 'GET'
    ApiUri = "git/repositories/vegadw/pullrequests/"
    ApiVersion = '6.0'
}
Invoke-AdoRestMethod @restMethodArgs

2. List all completed PRs

$restMethodArgs = @{
    PatToken = (gvct -Environment 'None').adoPatWorkItemRW
    RestMethod = 'GET'
    ApiUri = "git/repositories/vegadw/pullrequests/"
    ApiArgs = @{'searchCriteria.status' = 'completed'}
    ApiVersion = '6.0'
}
Invoke-AdoRestMethod @restMethodArgs

.NOTES

#>#>
Function Invoke-AdoRestMethod {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VstsAccount,
        [Parameter(Mandatory)]
        [string]$ProjectName,
        [Parameter()]
        [string]$TeamName,
        [Parameter()]
        [string]$User = "Personal Access Token",
        # typically  the PAT. If not provided we will try to get from the environment in case we are running on a Agent
        # Personal Access Token
        [Parameter()]
        [SecureString]$Password,
        # the uri path  after .../_apis/ e.g /wit/wiql?api-version=1.0
        [Parameter()]
        [string]$ApiUri,
        [Parameter()]
        [hashtable]$ApiArgs = @{},
        [Parameter(Mandatory)]
        [string]$ApiVersion,
        [Parameter()]
        [PSCustomObject]$Body,
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'HEAD', 'PUT', 'POST', 'PATCH')]
        [string]$RestMethod,
        [Parameter()]
        [string]$ContentType = 'application/json'
    )

    if ($Password) {
        # Base64-encodes the Personal Access Token (PAT) appropriately
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, ($Password | ConvertFrom-SecureString -AsPlainText))))
        }
        else {
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))))))
        }

        $headers = @{
            Authorization = ("Basic {0}" -f $base64AuthInfo)
        }
    }
    else {
        if (!($env:SYSTEM_ACCESSTOKEN )) {
            throw ("The variable (System.AccessToken) is misssing.
                    To enable scripts to use the build process OAuth token, go to the following path on Azure DevOps  ->  'Pipelines \ Releases \ <your pipeline> \ <your Stage> \ Agent Job \ Additional Options \ Allow scripts to access the OAuth Token'.")
        }

        $headers = @{
            Authorization = "Bearer $($env:SYSTEM_ACCESSTOKEN)"
        }
    }

    $uriParts = @(
        "https://$($vstsAccount).visualstudio.com"
        $projectName
        $(if ($TeamName) { "$($TeamName)/" } else { '' })
        '_apis'
        $ApiUri
    )
    $ApiArgs.Add('api-version', $ApiVersion)
    $uri = "$([string]::Join('/', $uriParts))?$([string]::join('&', ($ApiArgs.GetEnumerator() | ForEach-Object {"$($_.Name)=$($_.Value)"})))"

    "calling uri: $($uri)" | Write-Verbose

    [Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls -bor
    [Net.SecurityProtocolType]::Tls11 -bor
    [Net.SecurityProtocolType]::Tls12

    $restMethodArgs = @{
        Uri         = $uri
        Method      = $RestMethod
        ContentType = $ContentType
        Headers     = $headers
    }

    if ($Body) {
        $restMethodArgs.Body = $Body | ConvertTo-Json
        Write-Debug $restMethodArgs.Body
    }

    # Invoke the REST call and capture the results (notice this uses the PATCH method)
    if ($PSCmdlet.ShouldProcess("executing $RestMethod on $uri")) {

        $result = Invoke-RestMethod @restMethodArgs

        Write-Output $result
    }
}
