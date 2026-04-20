# powershellai.ps1 - jarvis / friday PowerShell helpers backed by psai.py
#
# Load once in the current session:
#     . "$PSScriptRoot\powershellai.ps1"
#
# Load on every PowerShell start: add this line to your $PROFILE:
#     . "C:\full\path\to\powershellai.ps1"
#
# Commands:
#     jarvis <request>    generate, (confirm if risky) run
#     friday <request>    generate, copy to clipboard, do NOT run
#
# Switches on both:
#     -NoClipboard        don't touch the clipboard
#     -NoLog              don't append to the audit log
# jarvis only:
#     -Yes                skip the confirmation prompt for this call

$script:PsAiRoot    = $PSScriptRoot
$script:PsAiPython  = Join-Path $PSScriptRoot 'psai.py'
$script:PsAiLogDir  = Join-Path $env:LOCALAPPDATA 'psai'
$script:PsAiLogFile = Join-Path $script:PsAiLogDir 'history.jsonl'

# A command built from ONLY these cmdlets runs without a confirmation prompt.
$script:PsAiSafeCmdletPatterns = @(
    'Get-*', 'Select-*', 'Measure-*', 'Compare-*', 'Group-*', 'Sort-*',
    'Where-Object', '?', 'ForEach-Object', '%',
    'Format-*', 'Out-Default', 'Out-String', 'Out-Host', 'Out-Null',
    'ConvertTo-*', 'ConvertFrom-*',
    'Write-Host', 'Write-Output', 'Write-Verbose', 'Write-Debug',
    'Test-Path', 'Test-Connection', 'Test-NetConnection',
    'Resolve-Path', 'Join-Path', 'Split-Path',
    'Import-Csv', 'Read-Host'
)

# Any cmdlet (or alias) here forces a strict 'type yes' confirmation.
$script:PsAiDangerCmdlets = @(
    'Invoke-Expression', 'iex',
    'Invoke-Command', 'icm',
    'Invoke-WebRequest', 'iwr', 'curl', 'wget',
    'Invoke-RestMethod', 'irm',
    'Start-Process', 'saps',
    'Remove-Item', 'ri', 'rm', 'rmdir', 'del', 'erase', 'rd',
    'Clear-Content', 'Clear-Item',
    'Format-Volume', 'Remove-Partition', 'Set-Disk',
    'Stop-Computer', 'Restart-Computer',
    'Stop-Process', 'kill', 'spps',
    'Stop-Service', 'Set-Service',
    'Disable-LocalUser', 'Remove-LocalUser', 'New-LocalUser', 'Set-LocalUser',
    'Remove-ADUser', 'Remove-ADGroup', 'Set-ADUser',
    'Remove-PSDrive', 'Remove-ItemProperty', 'Set-ItemProperty',
    'Set-ExecutionPolicy',
    'Register-ScheduledTask', 'Unregister-ScheduledTask'
)

function Write-PsAiLog {
    param(
        [string]$Mode,
        [string]$Prompt,
        [string]$Command,
        [string]$Action
    )
    try {
        if (-not (Test-Path $script:PsAiLogDir)) {
            New-Item -ItemType Directory -Path $script:PsAiLogDir -Force | Out-Null
        }
        $entry = [ordered]@{
            ts      = (Get-Date).ToString('o')
            mode    = $Mode
            prompt  = $Prompt
            command = $Command
            action  = $Action
        } | ConvertTo-Json -Compress
        Add-Content -Path $script:PsAiLogFile -Value $entry -Encoding UTF8
    } catch {
        Write-Verbose "psai log write failed: $_"
    }
}

function Test-PsAiCommandSafety {
    param([string]$Command)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Command, [ref]$tokens, [ref]$errors
    )
    if ($errors -and $errors.Count -gt 0) {
        return [pscustomobject]@{
            Status    = 'ParseError'
            Reason    = $errors[0].Message
            Commands  = @()
            Dangerous = @()
        }
    }

    $invoked = @()
    if ($ast) {
        $invoked = $ast.FindAll(
            { param($n) $n -is [System.Management.Automation.Language.CommandAst] },
            $true
        ) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
    }

    $dangerous = $invoked | Where-Object { $script:PsAiDangerCmdlets -contains $_ }
    if ($dangerous) {
        return [pscustomobject]@{
            Status    = 'Dangerous'
            Commands  = $invoked
            Dangerous = @($dangerous)
        }
    }

    $allSafe = ($invoked.Count -gt 0)
    foreach ($c in $invoked) {
        $match = $false
        foreach ($pat in $script:PsAiSafeCmdletPatterns) {
            if ($c -like $pat) { $match = $true; break }
        }
        if (-not $match) { $allSafe = $false; break }
    }

    if ($allSafe) {
        return [pscustomobject]@{
            Status    = 'Safe'
            Commands  = $invoked
            Dangerous = @()
        }
    }

    return [pscustomobject]@{
        Status    = 'Unknown'
        Commands  = $invoked
        Dangerous = @()
    }
}

function Invoke-PsAi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('jarvis', 'friday')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments,

        [switch]$NoClipboard,
        [switch]$NoLog,
        [switch]$Yes
    )

    if (-not (Test-Path $script:PsAiPython)) {
        Write-Error "psai.py not found at $script:PsAiPython"
        return
    }

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Write-Warning "$Mode: no prompt given."
        return
    }

    $prompt = ($Arguments -join ' ').Trim()

    $output = & python $script:PsAiPython --wake $Mode -- @Arguments
    $exit = $LASTEXITCODE

    if ($exit -ne 0) {
        Write-Warning "$Mode: psai.py exited with code $exit."
        return
    }

    $cmd = if ($output) { ($output -join [Environment]::NewLine).Trim() } else { '' }
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-Warning "$Mode: empty response from the model."
        return
    }

    Write-Host ("{0} generated:" -f $Mode) -ForegroundColor Yellow
    Write-Host $cmd -ForegroundColor Cyan

    if (-not $NoClipboard) {
        try { $cmd | Set-Clipboard } catch { Write-Verbose "clipboard copy failed: $_" }
    }

    if ($Mode -eq 'friday') {
        if (-not $NoLog) {
            Write-PsAiLog -Mode $Mode -Prompt $prompt -Command $cmd -Action 'print'
        }
        return
    }

    # --- jarvis from here ---
    $safety = Test-PsAiCommandSafety -Command $cmd

    switch ($safety.Status) {
        'ParseError' {
            Write-Warning ("Could not parse generated command ({0}). NOT executing." -f $safety.Reason)
            if (-not $NoLog) {
                Write-PsAiLog -Mode $Mode -Prompt $prompt -Command $cmd -Action 'block-parseerror'
            }
            return
        }
        'Dangerous' {
            Write-Warning ("Risky cmdlets detected: {0}" -f ($safety.Dangerous -join ', '))
            if (-not $Yes) {
                $ans = Read-Host "Run anyway? (type 'yes' to confirm)"
                if ($ans -ne 'yes') {
                    Write-Host 'Aborted.' -ForegroundColor Red
                    if (-not $NoLog) {
                        Write-PsAiLog -Mode $Mode -Prompt $prompt -Command $cmd -Action 'block-dangerous'
                    }
                    return
                }
            }
        }
        'Unknown' {
            if (-not $Yes) {
                $ans = Read-Host 'Run this command? (y/N)'
                if ($ans -notmatch '^(y|yes)$') {
                    Write-Host 'Aborted.' -ForegroundColor Red
                    if (-not $NoLog) {
                        Write-PsAiLog -Mode $Mode -Prompt $prompt -Command $cmd -Action 'block-unknown'
                    }
                    return
                }
            }
        }
        'Safe' { }
    }

    Write-Host 'Running...' -ForegroundColor Green
    if (-not $NoLog) {
        Write-PsAiLog -Mode $Mode -Prompt $prompt -Command $cmd -Action 'run'
    }
    Invoke-Expression $cmd
}

function jarvis {
    [CmdletBinding()]
    param(
        [switch]$Yes,
        [switch]$NoClipboard,
        [switch]$NoLog,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ArgsFromUser
    )
    Invoke-PsAi -Mode jarvis -Arguments $ArgsFromUser `
        -Yes:$Yes -NoClipboard:$NoClipboard -NoLog:$NoLog
}

function friday {
    [CmdletBinding()]
    param(
        [switch]$NoClipboard,
        [switch]$NoLog,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ArgsFromUser
    )
    Invoke-PsAi -Mode friday -Arguments $ArgsFromUser `
        -NoClipboard:$NoClipboard -NoLog:$NoLog
}
