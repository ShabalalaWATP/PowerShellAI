function jarvis {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ArgsFromUser
    )

    $text = $ArgsFromUser -join ' '

    $cmd = python "C:\AlexDev\ps\jarvis.py" $text

    if (-not $cmd) {
        Write-Warning "Jarvis didn't return a command."
        return
    }

    Write-Host "Jarvis generated:" -ForegroundColor Yellow
    Write-Host $cmd -ForegroundColor Cyan

    $cmd | Set-Clipboard

    $blocked = @(
        "Remove-Item",
        "format-volume",
        "Clear-Content",
        "Stop-Computer",
        "Restart-Computer",
        "Disable-LocalUser",
        "del C:\",
        "Remove-ADUser"
    )
    foreach ($pat in $blocked) {
        if ($cmd -like "*$pat*") {
            Write-Warning "Blocked potentially dangerous command: $pat"
            return
        }
    }

    Write-Host "Running..." -ForegroundColor Green
    Invoke-Expression $cmd
}

function friday {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ArgsFromUser
    )

    $text = $ArgsFromUser -join ' '

    $cmd = python "C:\AlexDev\ps\friday.py" $text

    if (-not $cmd) {
        Write-Warning "Friday didn't return a command."
        return
    }

    Write-Host "Friday generated (not running):" -ForegroundColor Yellow
    Write-Host $cmd -ForegroundColor Cyan

    $cmd | Set-Clipboard
}
