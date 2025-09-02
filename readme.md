# PSEasy.AzureDevOps

A bunch of Powershell functions that can help automate aspects of AzureDevOps

## How to get the module

``` powershell
Install-Module PSEasy.AzureDevOps
```

## How to setup, and update this module

- Get PSEasy.Module helpers

```
Install-Module PSEasy.Module
```

- Create a "..Build-Module.config.json" file in the module root e.g.

    ``` json
    {
        "Manifest": {
            "Guid": "04dabf3f-0eb5-4ca5-a96b-4c66759a46d7",
            "Author": "Brett Gerhardi",
            "Description": "Helpers to automate Azure DevOps tasks",
            "ProjectURI": "https://github.com/o-o00o-o/PSEasy.AzureDevOps",
            "Tags": "PSEdition_Core"
        },
        "File":{
            "FileSpec": "*-*.ps1",
            "ExcludeSpec": ["*.Tests.ps1", "--*.ps1"],
            /* "PublicOnlyIfIndicated" or "'PublicByDefault" */
            "ExportMode": "PublicByDefault"
        }
    }
    ```

    - Manifest properties are static values that will be put into the psd1 file as is
    - File properties are to determine the files to include/exclude and how to decide those files to export

- Put your functions into a folder structure \<MyModule>\\\<MyFunctions>
    - Files or folders with private or public in the name will always be private or public. You can indicate a default when building to deal with the others
    - No scripts, all files should contain functions

- Validate and Build the psd1/psm1 files by running ```Build-Module```

    ``` powershell
    Build-Module .\module\PSEasy.AzureDevOps\ -Import
    ```

    - Import switch to import directly into the current session (note that any scripts with #requires for this module will reload the installed version - so useful for local testing only)
    - Load switch ensures that it can be loaded into a new session correctly

- Locally install the module (not generally needed)

    ``` powershell
    Install-ModuleFromFolder .\module\PSEasy.AzureDevOps\
    ```

    > Note this doesn't increment the version and will just overwrite the existing version. Useful for testing without generating loads of version numbers

- Now publish it
    - You can use either the standard ```Publish-Module``` to publish to Powershell Gallery or see PSEasy.Module for publishing to ADO artifact feed
    - If you use ```Publish-Module``` then you can use the ```Set-ModuleVersion``` to increment the version in all the places necessary

    e.g.

    ``` powershell
    Set-ModuleVersion -modulepath '.\module\PSEasy.AzureDevOps\' -VersionIncrementType Patch
    Publish-Module -path '.\module\PSEasy.AzureDevOps\' -Verbose -NuGetApiKey 'Your key here' -whatif
    ```

    setup your profile with an easy to use by putting the below in your ```code $profile``` (setup the file with the commented code)
    ```
    <#
    setup encrypted password one-time with

    $password = Read-Host "Enter Password" -AsSecureString
    $fileLocation = '~\PsEasy.NuGetApiKey.user.secret'
    Set-Content -Path $fileLocation -Value $password -Force
    #>

    $global:PsEasyNuGetApiKey = Get-Content $fileLocation | ConvertTo-SecureString

    function Get-PSEasyNuGetApiKey {($PsEasyNuGetApiKey | ConvertFrom-SecureString -AsPlainText)}
    ```

    then use this safely with
    # Publish-Module -path ..\..\PSEasy\PSEasy.Utility\PSEasy.AzureDevOps\ -Verbose -NuGetApiKey (Get-PsEasyNuGetApiKey) -Whatif
    # then run without whatif if no errors
    ```

## Notes for working on this library

Of course there is a bit of a chicken and egg problem using Build-Module for this module if you are changing the code in Build-Module

To workaround that use

``` powershell
. src\module\Lifecycle\Import-ModuleFunction
```
