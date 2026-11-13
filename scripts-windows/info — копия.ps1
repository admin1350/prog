# Настройка кодировки для корректного отображения кириллицы
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== СБОР РАСШИРЕННОЙ ИНФОРМАЦИИ О СИСТЕМЕ ===" -ForegroundColor Cyan

# 1. Имя компьютера
Write-Host "`n[1] Имя ПК: " -NoNewline -ForegroundColor Yellow
Write-Host $env:COMPUTERNAME

# 2. Сетевые подключения, скорость и имя Wi-Fi
Write-Host "`n[2] Активные сетевые подключения:" -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

if ($adapters) {
    foreach ($adapter in $adapters) {
        # Получаем IPv4 адрес
        $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ip = if ($ipInfo) { $ipInfo.IPAddress } else { "Нет IPv4" }
        
        # Получаем скорость линка (в Мбит/с или Гбит/с)
        $speed = if ($adapter.LinkSpeed) { $adapter.LinkSpeed } else { "Неизвестно" }

        # Проверяем, является ли адаптер Wi-Fi
        $isWifi = $adapter.InterfaceDescription -match "Wi-Fi|Wireless|802\.11" -or $adapter.Name -match "Wi-Fi|Беспроводная"
        
        if ($isWifi) {
            # Узнаем имя текущей сети Wi-Fi (SSID) через встроенную утилиту netsh
            $wlanInfo = netsh wlan show interfaces | Select-String "^\s*SSID\s*:"
            $ssid = if ($wlanInfo) { ($wlanInfo -split ":")[1].Trim() } else { "Не определено" }
            $connType = "Wi-Fi (Сеть: $ssid)"
        } else {
            $connType = "Ethernet (Кабель) / Другое"
        }

        Write-Host " - Интерфейс: $($adapter.Name) ($($adapter.InterfaceDescription))"
        Write-Host "   Тип:       $connType" -ForegroundColor Green
        Write-Host "   Скорость:  $speed"
        Write-Host "   IP-адрес:  $ip`n"
    }
} else {
    Write-Host " - Активных подключений не найдено.`n" -ForegroundColor Red
}

# 3. Статус активации Windows
Write-Host "[3] Статус активации Windows:" -ForegroundColor Yellow
$winEdition = (Get-CimInstance Win32_OperatingSystem).Caption
Write-Host " - Редакция:  $winEdition"

# Проверяем статус лицензии Windows через WMI (ApplicationID для Windows)
$winLicense = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue

if ($winLicense) {
    $statusText = switch ($winLicense.LicenseStatus) {
        1 { "Активирована (Лицензия в порядке)" }
        2 { "Льготный период (OOB Grace)" }
        3 { "Льготный период (OOT Grace)" }
        4 { "Неподлинная копия (Non-Genuine)" }
        5 { "Уведомление (Требуется активация)" }
        default { "Не активирована (Код: $($winLicense.LicenseStatus))" }
    }
    $color = if ($winLicense.LicenseStatus -eq 1) { "Green" } else { "Red" }
    Write-Host " - Статус:    $statusText" -ForegroundColor $color
} else {
    Write-Host " - Статус:    Не активирована (Ключ продукта не найден)" -ForegroundColor Red
}

# 4. Наличие Microsoft Office и его активация
Write-Host "`n[4] Microsoft Office:" -ForegroundColor Yellow
# Ищем установленные продукты Office в реестре
$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$officeApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
              Where-Object { $_.DisplayName -match "Microsoft Office|Microsoft 365" -and $_.DisplayName -notmatch "MUI|Proof|Language|Update" } |
              Select-Object -ExpandProperty DisplayName -Unique

if ($officeApps) {
    foreach ($app in $officeApps) {
        Write-Host " - Установлен: $app"
    }
    
    # Проверяем статус лицензии Office через WMI (ApplicationID для Office 2013/2016/2019/2021/365)
    $offLicenses = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID = '0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue
    
    if ($offLicenses) {
        foreach ($lic in $offLicenses) {
            $offStatus = switch ($lic.LicenseStatus) {
                1 { "Активирован" }
                2 { "Льготный период (Требует активации)" }
                5 { "Уведомление (Срок действия истек)" }
                default { "Не активирован (Код: $($lic.LicenseStatus))" }
            }
            $offColor = if ($lic.LicenseStatus -eq 1) { "Green" } else { "Red" }
            Write-Host " - Лицензия ($($lic.Name)): $offStatus" -ForegroundColor $offColor
        }
    } else {
        Write-Host " - Статус активации: Ключ не найден (Возможно, Office не активирован или используется подписка через аккаунт)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host " - Microsoft Office не найден на этом ПК." -ForegroundColor Gray
}

# 5. Список всех установленных программ
Write-Host "`n[5] Все установленные программы:" -ForegroundColor Yellow
$allRegPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$programs = Get-ItemProperty $allRegPaths -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -ne $null } | 
            Select-Object -ExpandProperty DisplayName -Unique | 
            Sort-Object

foreach ($prog in $programs) {
    Write-Host " - $prog"
}

Write-Host "`n=== ГОТОВО ===" -ForegroundColor Cyan
Read-Host "Нажмите Enter для выхода"
