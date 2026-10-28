<#
.SYNOPSIS
    Met à jour la resource 7PVP sur le VPS (hôte SSH "seven") depuis GitHub.

.DESCRIPTION
    La resource du VPS est un clone de github.com/Wz-FiveM/7PVP (branche main).
    1. Pousse les commits locaux pas encore sur GitHub (les fichiers non commités ne partent pas).
    2. Sur le VPS (tools/update.sh) : git pull, puis recompile l'interface si web/ a changé.
    3. Avec -Redemarrer : redémarre le serveur (service systemd 7pvp) et attend qu'il réponde.

.EXAMPLE
    .\deploy.bat                met à jour (sans redémarrer)
    .\deploy.bat -Redemarrer    met à jour puis redémarre le serveur
    .\deploy.bat -Apercu        liste les commits qui arriveraient, sans rien modifier
    .\deploy.bat -Restaurer     revient à la version d'avant la dernière mise à jour
#>
param(
    [switch]$Redemarrer,
    [switch]$Apercu,
    [switch]$Restaurer,
    # Redémarre sans demander, même avec des joueurs connectés
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$Vps = @{
    Ssh = 'seven'                                     # hôte de ~/.ssh/config
    Resource = '/opt/7pvp/server-data/resources/7PVP'
    Service = '7pvp'
    Players = 'http://145.239.149.134:30121/players.json'
    TxAdmin = 'http://145.239.149.134:40121'
}

$Root = Split-Path $PSScriptRoot -Parent

function Step([string]$Text) {
    Write-Host "`n> $Text" -ForegroundColor Cyan
}

# Lance une commande externe et s'arrête si elle échoue
function Run([string]$Label, [scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label a échoué (code $LASTEXITCODE)." }
}

function Get-OnlinePlayers {
    try {
        # FiveM ne répond pas en application/json : PowerShell 5.1 rend alors le contenu brut (octets)
        $response = Invoke-WebRequest -Uri $Vps.Players -TimeoutSec 5 -UseBasicParsing
        $json = $response.Content
        if ($json -is [byte[]]) { $json = [Text.Encoding]::UTF8.GetString($json) }
        # Pas de pipeline : PowerShell 5.1 y passerait le tableau comme un seul objet
        $players = ConvertFrom-Json $json
        return @($players).Count
    } catch {
        return $null
    }
}

function Restart-Server {
    $online = Get-OnlinePlayers
    if ($online -gt 0 -and -not $Force) {
        $answer = Read-Host "$online joueur(s) en ligne. Redémarrer quand même ? (o/N)"
        if ($answer -notmatch '^o') {
            Write-Host "Pas de redémarrage. Les fichiers seront pris en compte au prochain (ou : restart 7PVP dans la console txAdmin)."
            return
        }
    }

    Step "Redémarrage du serveur"
    Run 'Le redémarrage' { ssh $Vps.Ssh "sudo systemctl restart $($Vps.Service)" }

    # txAdmin relance FXServer : on attend que le serveur de jeu réponde
    $deadline = (Get-Date).AddSeconds(120)
    do {
        Start-Sleep -Seconds 5
        if ($null -ne (Get-OnlinePlayers)) {
            Write-Host "Serveur en ligne." -ForegroundColor Green
            return
        }
    } while ((Get-Date) -lt $deadline)
    Write-Warning "Le serveur ne répond pas après 2 minutes : vérifie dans txAdmin ($($Vps.TxAdmin))."
}

if (-not $Restaurer) {
    Push-Location $Root
    try {
        $dirty = git status --porcelain
        if ($dirty) {
            Write-Warning "Modifications non commitées : elles ne partent pas sur le VPS."
        }
        Run 'git fetch' { git fetch --quiet }
        $ahead = [int](git rev-list --count '@{u}..HEAD')
        if ($ahead -gt 0 -and -not $Apercu) {
            Step "Envoi de $ahead commit(s) sur GitHub"
            Run 'git push' { git push --quiet }
        } elseif ($ahead -gt 0) {
            Write-Host "$ahead commit(s) local(aux) pas encore sur GitHub (envoyés sans -Apercu)."
        }
    } finally {
        Pop-Location
    }
}

$mode = if ($Restaurer) { '--restaurer' } elseif ($Apercu) { '--apercu' } else { '' }
Step $(if ($Restaurer) { "Restauration de la version précédente" } elseif ($Apercu) { "Aperçu des changements" } else { "Mise à jour de la resource" })
Run 'La mise à jour' { ssh $Vps.Ssh "bash '$($Vps.Resource)/tools/update.sh' $mode" }

if ($Apercu) { exit 0 }

if ($Redemarrer) {
    Restart-Server
} else {
    Write-Host "`nFichiers à jour. Pour les appliquer : .\deploy.bat -Redemarrer, ou « restart 7PVP » dans la console txAdmin ($($Vps.TxAdmin))." -ForegroundColor Green
}
