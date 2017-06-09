
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

    Function Get-ParsedMoodleSite
    {
        Param(
            $UnpackedBackupDirectory
        )
        $MoodleBackup  = $([xml]$(Get-Content "$UnpackedBackupDirectory\moodle_backup.xml")).moodle_backup.information

        Add-Member -NotePropertyName "Files" -NotePropertyvalue $([xml]$(Get-Content "$UnpackedBackupDirectory\Files.xml")).files.file -InputObject $MoodleBackup

        $Sections = Foreach($Section in $MoodleBackup.contents.sections.section)
        {
            $fileIDs = $([xml]$(Get-Content "$UnpackedBackupDirectory\$($section.directory)\inforef.xml")).inforef.fileref.file

            $Files =  Foreach($FileID in $FileIDs.id)
            {
                $MoodleBackup.files | Where-Object {$_.id -eq $FileID}
            }
            Add-Member -NotePropertyName "Files" -NotePropertyvalue $Files -InputObject $section


            $section
        }


        Add-Member -NotePropertyName "Sections"  -InputObject $MoodleBackup -NotePropertyvalue $Sections

        $Activities = Foreach($Activity in $MoodleBackup.contents.activities.activity)
        {
            $fileIDs = $([xml]$(Get-Content "$UnpackedBackupDirectory\$($Activity.directory)\inforef.xml")).inforef.fileref.file

            $Files =  Foreach($FileID in $FileIDs.id)
            {
                $MoodleBackup.files | Where-Object {$_.id -eq $FileID}
            }
            Add-Member -NotePropertyName "Files" -NotePropertyvalue $Files -InputObject $Activity
            

            $Activity
        }
        Add-Member -NotePropertyName "Activities"  -InputObject $MoodleBackup -NotePropertyvalue $Activities

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
                
                $Hash2 = $($File.contenthash).substring(0,2)
                $Source = "$UnpackedBackupDirectory\files\$Hash2\$($File.contenthash)"
                $Destination = "$SectionTargetDir\$($file.filename)"
                Write-Host -ForegroundColor Cyan "Copying $Destination"
                try{
                     Copy-Item -Path $Source -Destination $Destination -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Couldn't copy file: $($File.filename)"
                }
               
            }
        }
        Foreach ($Activity in $Site.Activities)
        {
            Write-Host -ForegroundColor Green "Starting Activity: $($Activity.Title) with $($Activity.Files.Count) Files"
            $ActivityTargetDir = "$TargetDirectory\Activities\$($Activity.Title)"
            if (-Not $(Test-Path $ActivityTargetDir))
            {
                New-Item -ItemType Directory -Path $ActivityTargetDir | Out-Null
            }
            Foreach ($File in $Activity.files) 
            {
                
                $Hash2 = $($File.contenthash).substring(0,2)
                $Source = "$UnpackedBackupDirectory\files\$Hash2\$($File.contenthash)"
                $Destination = "$ActivityTargetDir\$($file.filename)"
                Write-Host -ForegroundColor Cyan "Copying $Destination"
                try{
                     Copy-Item -Path $Source -Destination $Destination -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Couldn't copy file: $($File.filename)"
                }
               
            }
        }
    }

#endregion

#Expand-MoodleSite "$PSScriptRoot\Backups\HCC.mbz"

$Src = "$PSScriptRoot\Target\HCC\RawBackup"
$target = "$PSScriptRoot\Target\HCC\ParsedBackup"
$MoodleSite = Get-ParsedMoodleSite -UnpackedBackupDirectory $Src

Extract-SiteFiles -UnpackedBackupDirectory $Dir -Site $MoodleSite -TargetDirectory $target