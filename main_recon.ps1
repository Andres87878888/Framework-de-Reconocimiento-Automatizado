# main_recon.ps1 - Framework Ultimate (Versión Final con Wordlist Local)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$basePath = Get-Location
$logDir = Join-Path $basePath "logs"
$reportDir = Join-Path $basePath "reportes"
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"

# --- CONFIGURACION DE APIS ---
$abuseKey = "" 

if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir }
if (!(Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir }

Write-Host "--- Recon Framework Ultimate Inicializado ---" -ForegroundColor Cyan

# ==========================================
# 1. MODULO DE COMPROBACION DE REQUISITOS (Pre-flight)
# ==========================================
Write-Host "`n[*] Verificando herramientas instaladas..." -ForegroundColor Yellow
$wslTest = Get-Command wsl -ErrorAction SilentlyContinue
if (!$wslTest) {
    Write-Host "[!] ERROR: WSL no esta instalado o no se encuentra en el PATH de Windows." -ForegroundColor Red
    Exit
}

$nmapTest = wsl which nmap
$subTest = wsl which subfinder
$ffufTest = wsl which ffuf

$missingTools = @()
if ([string]::IsNullOrEmpty($nmapTest)) { $missingTools += "nmap" }
if ([string]::IsNullOrEmpty($subTest)) { $missingTools += "subfinder" }
if ([string]::IsNullOrEmpty($ffufTest)) { $missingTools += "ffuf" }

if ($missingTools.Count -gt 0) {
    Write-Host "[!] Faltan herramientas en WSL: ($($missingTools -join ', '))." -ForegroundColor Red
    Write-Host "Por favor, instalalas en tu Ubuntu antes de continuar." -ForegroundColor Yellow
    Exit
}
Write-Host "[+] Requisitos listos. Iniciando auditoria..." -ForegroundColor Green

# --- Solicitud de Objetivo ---
$target = Read-Host "Introduce el dominio o IP (ej: scanme.nmap.org)"
$reportFile = Join-Path $reportDir "$target-audit-$timestamp.txt"
"--- Reporte de Auditoria: $target ---" | Out-File $reportFile
"Fecha: $(Get-Date)" | Out-File $reportFile -Append

# ==========================================
# 2. MODULO DE INTELIGENCIA DE AMENAZAS (Threat Intel)
# ==========================================
Write-Host "`n[*] Resolviendo IP y consultando reputacion..." -ForegroundColor Yellow
try {
    $ipAddresses = @([System.Net.Dns]::GetHostAddresses($target) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString)
    
    if ($ipAddresses.Count -eq 0) { throw "No se encontraron registros IPv4." }
    $ip = $ipAddresses[0]
    "IP Resuelta: $ip" | Out-File $reportFile -Append
    Write-Host "[+] IP de destino (IPv4): $ip" -ForegroundColor Green

    if ($abuseKey -ne "TU_API_KEY_AQUI" -and ![string]::IsNullOrEmpty($abuseKey)) {
        $headers = @{ "Key" = $abuseKey; "Accept" = "application/json" }
        $url = "https://api.abuseipdb.com/api/v2/check?ipAddress=$ip&maxAgeInDays=90"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        
        $score = $response.data.abuseConfidenceScore
        $totalReports = $response.data.totalReports
        
        $intelMsg = "[Threat Intel] Puntuacion de abuso: $score% | Reportes totales: $totalReports"
        
        $msgColor = if ($score -gt 20) { "Red" } else { "Green" }
        Write-Host $intelMsg -ForegroundColor $msgColor
        
        $intelMsg | Out-File $reportFile -Append
    } else {
        Write-Host "[!] Consulta a AbuseIPDB omitida (No se configuro API Key)." -ForegroundColor Gray
    }
} catch {
    Write-Host "[!] No se pudo resolver la IP o consultar la API de reputacion: $_" -ForegroundColor Red
}

# ==========================================
# 3. ENUMERACION Y ESCANEO DE PUERTOS
# ==========================================
Write-Host "`n[*] Buscando subdominios..." -ForegroundColor Yellow
wsl subfinder -d $target -silent | Out-File $reportFile -Append

Write-Host "[*] Escaneando puertos..." -ForegroundColor Yellow
$nmapPath = Join-Path $logDir "nmap_temp.txt"
wsl nmap -sV $target > $nmapPath
$puertos = Get-Content $nmapPath
$puertos | Out-File $reportFile -Append

# ==========================================
# 4. MODULO DE HARDENING / RECOMENDACIONES HIBRIDO
# ==========================================
"`n[Acciones y Recomendaciones de Hardening]" | Out-File $reportFile -Append

$isLocal = ($target -eq "localhost" -or $target -eq "127.0.0.1" -or $ip -eq "127.0.0.1")

# --- Remediacion para Linux ---
if ($puertos -match "22/tcp") {
    Write-Host "`n[!] Puerto 22 (SSH Linux) detectado." -ForegroundColor Yellow
    $cmdSSH = "sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && systemctl restart ssh"
    
    if ($isLocal) {
        $resp = Read-Host "¿Deshabilitar acceso root por SSH localmente? (S/N)"
        if ($resp -eq "S") {
            Write-Host "Escribe tu contrasena de sudo (si es necesario):" -ForegroundColor Magenta
            wsl bash -c "sudo $cmdSSH"
            if ($LASTEXITCODE -eq 0) {
                "   [+] SSH: Hardening aplicado localmente." | Out-File $reportFile -Append
                Write-Host "SSH Asegurado localmente." -ForegroundColor Green
            } else { "   [-] SSH: Fallo al aplicar hardening local." | Out-File $reportFile -Append }
        }
    } else {
        Write-Host "[Sugerencia de Mitigacion] Para asegurar el SSH del servidor remoto, ejecuta alli:" -ForegroundColor Cyan
        Write-Host "  sudo $cmdSSH" -ForegroundColor Gray
        "   [Sugerencia] SSH: Deshabilitar acceso root remotamente usando: sudo $cmdSSH" | Out-File $reportFile -Append
    }
}

# --- Remediacion para Windows ---
if ($puertos -match "3389/tcp") {
    Write-Host "`n[!] Puerto 3389 (RDP Windows) detectado." -ForegroundColor Yellow
    if ($isLocal) {
        $resp = Read-Host "¿Deseas deshabilitar RDP en este sistema local para proteccion? (S/N)"
        if ($resp -eq "S") {
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1
            "   [+] RDP: Servicio de Escritorio Remoto deshabilitado localmente." | Out-File $reportFile -Append
            Write-Host "RDP deshabilitado correctamente." -ForegroundColor Green
        }
    } else {
        Write-Host "[Sugerencia de Mitigacion] Restringir acceso al puerto 3389 por Firewall o deshabilitar RDP si no se usa." -ForegroundColor Cyan
        "   [Sugerencia] RDP: Restringir acceso al puerto 3389 mediante politicas de Firewall." | Out-File $reportFile -Append
    }
}

if ($puertos -match "445/tcp") {
    Write-Host "`n[!] Puerto 445 (SMB Windows) detectado." -ForegroundColor Yellow
    if ($isLocal) {
        $resp = Read-Host "¿Deseas deshabilitar el protocolo obsoleto SMBv1 de forma local? (S/N)"
        if ($resp -eq "S") {
            Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart
            "   [+] SMB: Protocolo SMBv1 deshabilitado localmente." | Out-File $reportFile -Append
            Write-Host "SMBv1 Deshabilitado." -ForegroundColor Green
        }
    } else {
        Write-Host "[Sugerencia de Mitigacion] Deshabilitar SMBv1 en el objetivo remoto para prevenir exploits (ej. EternalBlue)." -ForegroundColor Cyan
        "   [Sugerencia] SMB: Deshabilitar SMBv1 en el servidor remoto." | Out-File $reportFile -Append
    }
}

# ==========================================
# 5. FUZZING WEB (Version Robusta con Wordlist Local)
# ==========================================
if ($puertos -match "80/tcp" -or $puertos -match "443/tcp") {
    Write-Host "`n[*] Iniciando fuzzing de directorios..." -ForegroundColor Yellow
    $fuzzPath = Join-Path $logDir "fuzz_temp.txt"
    
    # Ruta actualizada a tu carpeta personal en WSL
    $wordlist = "/home/andres/wordlists/common.txt"
    
    # Verificamos si el archivo existe antes de ejecutar
    $checkFile = wsl ls $wordlist 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        wsl ffuf -u "http://$target/FUZZ" -w $wordlist > $fuzzPath 2>&1
        Get-Content $fuzzPath | Out-File $reportFile -Append
        Write-Host "[*] Fuzzing finalizado." -ForegroundColor Green
    } else {
        Write-Host "[!] ERROR: No se encontro el archivo de wordlist en $wordlist. Fuzzing omitido." -ForegroundColor Red
        "   [!] Fuzzing omitido: Wordlist no encontrada en $wordlist" | Out-File $reportFile -Append
    }
}

Write-Host "`nReporte final disponible en: $reportFile" -ForegroundColor Cyan