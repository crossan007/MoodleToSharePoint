


function Split-Types {
    param(
        $Pattern,
        $Target
    )
    Get-ChildItem | ?{$_.BaseName -like "*$Pattern*"} | Move-Item -Destination $Target
}


function ParseDate([string]$date)
{
    $DateInfo = new-object system.globalization.datetimeformatinfo
    $DateNameMatch = $($DateInfo.MonthGenitiveNames | ?{$date -like "*$_*"})[0]
    if ($DateNameMatch)
    {
        $date -match '[\d]{1,2}' | out-null
        $day = $matches[0]
        $date -match '\d\d\d\d' | out-null
        $year = $matches[0]
        $date = "{0}-{1}-{2}" -F $day,$DateNameMatch,$year
    }
    elseif ($($date -split " ").count -gt 1)
    {
        $date = $($date -split " ")[0]
    }
    $result = 0
    if (!([DateTime]::TryParse($date, [ref]$result)))
    {
        throw "You entered an invalid date: $date"
     }

    $result
}



Function Fix-Date
{
    Get-ChildItem | Foreach-Object {
        $Parent = $_
        Write-Host -ForegroundColor Green "Processing Folder $($Parent.FullName)"
        $ChildDate = $null
        try {
            $ChildDate = ParseDate $($Parent.BaseName)
            Write-Host "Found Date $ChildDate"

            Get-ChildItem -Path $Parent | Foreach-Object {
                Write-Host -ForegroundColor Cyan "Fixing $($_.FullName) to modified date of $ChildDate"
                $_.LastWriteTime = $ChildDate
            }
         }
        catch {
            Write-Error "Couldn't parse parent date"
        }
    }
}