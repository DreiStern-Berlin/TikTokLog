function TikTokLog {

    param(
        [Parameter(Mandatory=$true)][Alias('h')][string]$Host,
        [Parameter(Mandatory=$false)][Alias('H1')][string[]]$Highlight,
        [Parameter(Mandatory=$false)][Alias('H2')][string[]]$Highlight2,
        [Parameter(Mandatory=$false)][Alias('c')][string]$ConfigPath = ".\config.json",
        [string]$ScriptPath = ".\chat-tail.js"
        )

    $esc = "`e["
    $reset  = "${esc}0m"

    $bgBlack        = "${esc}40m"
    $bgRed          = "${esc}41m"
    $bgGreen        = "${esc}42m"
    $bgYellow       = "${esc}43m"
    $bgBlue         = "${esc}44m"
    $bgMagenta      = "${esc}45m"
    $bgCyan         = "${esc}46m"
    $bgWhite        = "${esc}47m"

    $bgBrightBlack  = "${esc}100m"
    $bgBrightRed    = "${esc}101m"
    $bgBrightGreen  = "${esc}102m"
    $bgBrightYellow = "${esc}103m"
    $bgBrightBlue   = "${esc}104m"
    $bgBrightMagenta= "${esc}105m"
    $bgBrightCyan   = "${esc}106m"
    $bgBrightWhite  = "${esc}107m"
  
    $bgOrange       = "${esc}48;5;208m"
    $bgPink         = "${esc}48;5;205m"
    $bgPurple       = "${esc}48;5;93m"
    $bgTeal         = "${esc}48;5;37m"
    $bgLime         = "${esc}48;5;118m"
    $bgGold         = "${esc}48;5;220m"
    $bgDarkRed      = "${esc}48;5;52m"
    $bgDarkBlue     = "${esc}48;5;17m"
    $bgDarkGreen    = "${esc}48;5;22m"
    $bgGray         = "${esc}48;5;240m"
    $bgLightGray    = "${esc}48;5;250m"

    $bgUser1 = "${esc}48;5;220m"   # Gold
    $bgUser2 = "${esc}48;5;118m"   # Lime
    $bgUser3 = "${esc}48;5;208m"   # Orange
    $bgUser4 = "${esc}48;5;205m"   # Pink
    $bgUser5 = "${esc}48;5;93m"    # Purple


    $bgText1 = "${esc}48;5;52m"    # Dunkelrot
    $bgText2 = "${esc}48;5;17m"    # Dunkelblau
    $bgText3 = "${esc}48;5;22m"    # Dunkelgrün
    $bgText4 = "${esc}48;5;240m"   # Dunkelgrau
    $bgText5 = "${esc}48;5;208m"   # Orange


    $bgUser = $bgDarkRed  
    $bgText = $bgRed   
    




    # --- Config laden ---
    $moduleRoot = $PSScriptRoot
    $configPath = Join-Path $moduleRoot "config.json"

    if (!(Test-Path $configPath)) {
        Write-Host "config.json nicht gefunden: $configPath" -ForegroundColor Red
        return
    }

    $cfg = Get-Content $configPath | ConvertFrom-Json

    # --- Host in config suchen ---
    $entry = $cfg.Hosts | Where-Object {
        $_.name -eq $Host -or $_.nick -eq $Host
    }

    if (-not $entry) {
        Write-Host "Host '$Host' nicht in config.json gefunden." -ForegroundColor Red
        return
    }

    $hostName = $entry.name
    $hostNick = $entry.nick

 
    # --- Basis-Logverzeichnis aus config.json ---
    $baseLogDir = $cfg.LogDirectory
    if (-not (Split-Path $baseLogDir -IsAbsolute)) {
        $baseLogDir = Join-Path $moduleRoot $baseLogDir
    }

    # --- Host-spezifischer Logordner ---
    $hostDirName = ($hostName -replace '[^a-zA-Z0-9._-]', '_')
    $hostLogDir = Join-Path $baseLogDir $hostDirName

    if (!(Test-Path $hostLogDir)) {
        Write-Host "Log-Ordner existiert nicht: $hostLogDir" -ForegroundColor Red
        return
    }

    # --- Neueste Logdatei finden ---
    $latest = Get-ChildItem -Path $hostLogDir -Filter "*.log" |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1

    if (-not $latest) {
        Write-Host "Keine Logdateien gefunden in: $hostLogDir" -ForegroundColor Red
        return
    }

    Write-Host "Tailing: $($latest.FullName)" -ForegroundColor Cyan

    # --- Live Tail + Formatierung ---
    Get-Content -Path $latest.FullName -Wait |
        ForEach-Object {
            try {
                $obj = $_ | ConvertFrom-Json -ErrorAction Stop
                $tsRaw = $obj.timestamp
                try {
                    $dt  = [datetime]::Parse($tsRaw, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal)
                    $ts  = $dt.ToLocalTime().ToString()   # Systemformat + lokale Zeitzone
                }
                catch {
                    $ts = $tsRaw   # Fallback, falls mal was Komisches im Log steht
                }

                $nick = $obj.nick
                $user = $obj.username
                $text = $obj.text



                $finalText = $text

                foreach ($pattern in $Highlight2) {
                    $safe = [Regex]::Escape($pattern)
                    $finalText = $finalText -replace $safe, "$bgText5$pattern$reset"
                }


                $link = "https://www.tiktok.com/@$user"

                $nick = "`e]8;;$link`e\$nick`e]8;;`e\"
                
                $nickColored = $nick
                                
                if ($Highlight -contains $user) {
                    $nickColored = "$bgUser$nick$reset"
                }


 
                Write-Host "[$ts] " -NoNewline -ForegroundColor DarkGray
                Write-Host $nickColored -NoNewline -ForegroundColor Yellow
                Write-Host ": $finalText" -NoNewline -ForegroundColor White
                Write-Host " ($user)" -ForegroundColor DarkGray


            }
            catch {
                Write-Host $_ -ForegroundColor DarkGray
            }
        }
}

function Start-TikTokChatTail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias('h')][string]$Host= "Host1",
        [string]$ConfigPath = "config.json",
        [string]$ScriptPath = "chat-tail.js",
        [string]$WorkingDirectory = "C:\Users\holge\OneDrive\Dokumente\PowerShell\Modules\TikTokLog"
    )


    Write-Output "TikTok Chat Tail wird gestartet für Host '$Host'."
    # Prüfen ob Node existiert
    $node = "C:\Program Files\nodejs\node.exe"
    if (-not (Test-Path $node)) {
        throw "Node.exe wurde nicht gefunden unter: $node"
    }

    # Prüfen ob Working Directory existiert
    if (-not (Test-Path $WorkingDirectory)) {
        throw "WorkingDirectory existiert nicht: $WorkingDirectory"
    }

    # Absoluten Pfad für Script und Config erzeugen
    $scriptFull = Join-Path $WorkingDirectory $ScriptPath
    $configFull = Join-Path $WorkingDirectory $ConfigPath

    Write-Output "scriptFull: '$scriptFull'."
    Write-Output "configFull: '$configFull'."


    if (-not (Test-Path $scriptFull)) {
        throw "chat-tail.js wurde nicht gefunden: $scriptFull"
    }

    if (-not (Test-Path $configFull)) {
        throw "config.json wurde nicht gefunden: $configFull"
    }

    # Start-Job erzeugen
   Write-Output "Start-Job erzeugen:."

    $job = Start-Job -ScriptBlock {
    param(
        [string]$node,
        [string]$scriptFull,
        [Parameter(Mandatory=$true)][Alias('h')][string]$Host,
        [string]$configFull,
        [string]$WorkingDirectory
        )

        Set-Location $WorkingDirectory

        & $node $scriptFull --Host $Host --config $configFull

    } -ArgumentList $node, $scriptFull, $Host, $configFull, $WorkingDirectory

    Write-Output "$node, $scriptFull, $Host, $configFull, $WorkingDirectory"


    Write-Output "TikTok Chat Tail gestartet für Host '$Host'. Job-ID: $($job.Id)"
    return $job
}


Export-ModuleMember -Function @(
    'TikTokLog' 
    'Start-TikTokChatTail'
)

