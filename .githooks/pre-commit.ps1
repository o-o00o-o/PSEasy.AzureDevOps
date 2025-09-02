#requires -Modules PSEasy.Utility
try {
    $gitstatus = Get-GitStatus
    $files = $GitStatus.Index
    $gitRoot = Split-Path $GitStatus.GitDir -Parent

    foreach ($file in $files) {
        $filePath = Join-Path $gitRoot $file
        if (Test-Path $filePath) {
            $commonSplat = @{
                FileContent = (Get-Content $filePath)
                FilePath    = $FilePath
            }

            $Include = @('*.dtsx', '*.sql', '*.txt', '*.cs', '*.json', '*.xml', '*.ps1', '*.config')
            $Exclude = @(
                'Test-NoExposedPasswords.ps1' # we trust ourselves :)
            )
            Test-ContentNoPassword @commonSplat -Include $Include -Exclude $Exclude

            $excludeSplat = @{
                Exclude = @('*.auto.sql', '*.sln', '*.dtsx', '*.png', '*.*proj', '*.xlsx')
            }
            Test-ContentNoTab @commonSplat @excludeSplat
        }
    }
    exit 0 # allow commit
} catch {
    Write-Information "FAILED pre-commit: $_" -InformationAction Continue
    exit 1
}
