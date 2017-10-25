
if (-Not $(Get-Module 7Zip4Powershell))
{
    #Install-Module -Name 7Zip4Powershell
}

#region Funcitons

    Function Remove-InvalidFileNameChars {
    param(
        [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [String]$Name
    )

    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    return ($Name -replace $re)
    }

    Function Expand-TarGZ {
        Param(
            $Source,
            $Destination
        )
        Get-ChildItem "$PSScriptRoot\Temp" | Remove-Item
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
        mkdir "$PSScriptRoot\Target\$SiteName"
        Expand-TarGZ -Source $BackupFile -Destination "$PSScriptRoot\Target\$SiteName\RawBackup"
    }

    Function Get-ParsedMoodleSite
    {
        Param(
            $UnpackedBackupDirectory
        )
        $MoodleBackup  = $([xml]$(Get-Content "$UnpackedBackupDirectory\moodle_backup.xml")).moodle_backup.information

        Add-Member -NotePropertyName "Files" -NotePropertyvalue $([xml]$(Get-Content "$UnpackedBackupDirectory\Files.xml")).files.file -InputObject $MoodleBackup

        $Sections = @{} 
        
        Foreach($Section in $MoodleBackup.contents.sections.section)
        {
            $Section.Title = Remove-InvalidFileNameChars -Name $($Section.Title.Trim())
            $fileIDs = $([xml]$(Get-Content "$UnpackedBackupDirectory\$($section.directory)\inforef.xml")).inforef.fileref.file

            $Files =  Foreach($FileID in $FileIDs.id)
            {
                $MoodleBackup.files | Where-Object {$_.id -eq $FileID}
            }
            Add-Member -NotePropertyName "Files" -NotePropertyvalue $Files -InputObject $section


           $Sections[$section.sectionid] = $section
        }

        $Activities = Foreach($Activity in $MoodleBackup.contents.activities.activity)
        {
            $fileIDs = $([xml]$(Get-Content "$UnpackedBackupDirectory\$($Activity.directory)\inforef.xml")).inforef.fileref.file
            $Activity.Title = Remove-InvalidFileNameChars -Name $($Activity.Title.Trim())
            $Files =  Foreach($FileID in $FileIDs.id)
            {
                $MoodleBackup.files | Where-Object {$_.id -eq $FileID}
            }
            Add-Member -NotePropertyName "Files" -NotePropertyvalue $Files -InputObject $Activity
            
            If (-Not [bool]($Sections[$Activity.sectionid].PSobject.Properties.name -match "Activities")) 
            {
                Add-Member -NotePropertyName "Activities"  -InputObject  $Sections[$Activity.sectionid] -NotePropertyvalue @()
            }
            $Sections[$Activity.sectionid].Activities += $Activity
        }
        


        Add-Member -NotePropertyName "Sections"  -InputObject $MoodleBackup -NotePropertyvalue $($Sections.Values)
       

        $MoodleBackup
    }


    Function Extract-SiteFiles {
        Param(
            $UnpackedBackupDirectory,
            $Site,
            $TargetDirectory
        )
        Foreach ($Section in $Site.Sections)
        {
            Write-Host -ForegroundColor Green "Starting Seciton: $($Section.Title) with $($Section.Files.Count) Files"
            $SectionTargetDir = "$TargetDirectory\Sections\$($Section.Title)"
            if (-Not $(Test-Path $SectionTargetDir))
            {
                New-Item -ItemType Directory -Path $SectionTargetDir | Out-Null
            }
            Foreach ($File in $Section.files) 
            {
                if ($File.Filename -ne ".")
                {
                    $Hash2 = $($File.contenthash).substring(0,2)
                    $Source = "$UnpackedBackupDirectory\files\$Hash2\$($File.contenthash)"
                    $Destination = "$SectionTargetDir\$($file.filename)"
                    Write-Host -ForegroundColor Cyan "Copying $Destination"
                    try{
                        Copy-Item -Path $Source -Destination $Destination -ErrorAction Stop
                    }
                    catch {
                        Write-Error "Couldn't copy file: $($file.filename): $_"
                    }
                }
               
            }
            Foreach ($Activity in $Section.Activities)
            {
                Write-Host -ForegroundColor Green "Starting Activity: $($Activity.Title) with $($Activity.Files.Count) Files"
                $ActivityTargetDir = "$SectionTargetDir\Activities\$($Activity.Title)"
                if (-Not $(Test-Path $ActivityTargetDir))
                {
                    New-Item -ItemType Directory -Path $ActivityTargetDir | Out-Null
                }
                Foreach ($File in $Activity.files) 
                {
                    if ($File.Filename -ne ".")
                    {
                        $Hash2 = $($File.contenthash).substring(0,2)
                        $Source = "$UnpackedBackupDirectory\files\$Hash2\$($File.contenthash)"
                        $Destination = "$ActivityTargetDir\$($file.filename)"
                        Write-Host -ForegroundColor Cyan "Copying $Destination"
                        try{
                            Copy-Item -Path $Source -Destination $Destination -ErrorAction Stop
                        }
                        catch {
                            Write-Error "Couldn't copy file: $($file.filename): $_"
                        }
                    }             
                }
            }
        }
    }

    Function Upload-MoodleToSharePoint 
    {
        Param(
            $UnpackedBackupDirectory,
            $Site,
            $TargetDirectory
        )
    }

#endregion

Expand-MoodleSite "$PSScriptRoot\Backups\HRDirectors.mbz"
$Src = "$PSScriptRoot\Target\HRDirectors\RawBackup"
$target = "$PSScriptRoot\Target\HRDirectors"
$MoodleSite = Get-ParsedMoodleSite -UnpackedBackupDirectory $Src
#Extract-SiteFiles -UnpackedBackupDirectory $Src -Site $MoodleSite -TargetDirectory $target