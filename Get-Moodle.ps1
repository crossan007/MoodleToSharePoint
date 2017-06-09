
if (-Not $(Get-Module 7Zip4Powershell))
{
    Install-Module -Name 7Zip4Powershell
}

#region Funcitons

    Function Expand-TarGZ {
        Param(
            $Source,
            $Destination
        )
        Expand-7Zip -ArchiveFileName $Source -TargetPath "$PSScriptRoot\Temp"
        $File = $(Get-ChildItem "$PSScriptRoot\Temp" -Filter *.tar).FullName
        Expand-7Zip -ArchiveFileName $File -TargetPath $Destination
    }
    Function Expand-MoodleSite
    {
        Param(
            $BackupFile
        )
        $SiteName = $(Get-Item $BackupFile).BaseName
        Expand-TarGZ -Source $BackupFile -Destination "$PSScriptRoot\Target\$SiteName"
    }

#endregion

Expand-MoodleSite "$PSScriptRoot\Backups\HCC.mbz"
