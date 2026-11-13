# Настройка кодировки для корректного отображения кириллицы
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Создаем список для накопления строк отчета
$report = [System.Collections.Generic.List[string]]::new()

# Вспомогательная функция для одновременного вывода на экран и записи в отчет
function Add-Log {
    param (
        [string]$Text,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    Write-Host $Text -ForegroundColor $Color -NoNewline:$NoNewline
    if ($NoNewline) {
        if ($report.Count -gt 0) {
            $report[$report.Count - 1] += $Text
        } else {
            $report.Add($Text)
        }
    } else {
        $report.Add($Text)
    }
}

Add-Log "=== СБОР РАСШИРЕННОЙ ИНФОРМАЦИИ О СИСТЕМЕ ===" "Cyan"
Add-Log "Дата проверки: $(Get-Date -Format 'dd.MM.yyyy HH:mm')" "Gray"

# 1. Имя компьютера
$pcName = $env:COMPUTERNAME
Add-Log "`n Имя ПК: " "Yellow" -NoNewline
Add-Log $pcName

# 2. Сетевые подключения, скорость и имя Wi-Fi
Add-Log "`n Активные сетевые подключения:" "Yellow"
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

if ($adapters) {
    foreach ($adapter in $adapters) {
        $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ip = if ($ipInfo) { $ipInfo.IPAddress } else { "Нет IPv4" }
        $speed = if ($adapter.LinkSpeed) { $adapter.LinkSpeed } else { "Неизвестно" }

        $isWifi = $adapter.InterfaceDescription -match "Wi-Fi|Wireless|802\.11" -or $adapter.Name -match "Wi-Fi|Беспроводная"
        
        if ($isWifi) {
            $wlanInfo = netsh wlan show interfaces | Select-String "^\s*SSID\s*:"
            $ssid = if ($wlanInfo) { ($wlanInfo -split ":")[1].Trim() } else { "Не определено" }
            $connType = "Wi-Fi (Сеть: $ssid)"
        } else {
            $connType = "Ethernet (Кабель) / Другое"
        }

        Add-Log " - Интерфейс: $($adapter.Name) ($($adapter.InterfaceDescription))"
        Add-Log "   Тип:       $connType" "Green"
        Add-Log "   Скорость:  $speed"
        Add-Log "   IP-адрес:  $ip`n"
    }
} else {
    Add-Log " - Активных подключений не найдено.`n" "Red"
}

# 3. Статус активации Windows
Add-Log " Статус активации Windows:" "Yellow"
$winEdition = (Get-CimInstance Win32_OperatingSystem).Caption
Add-Log " - Редакция:  $winEdition"

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
    Add-Log " - Статус:    $statusText" $color
} else {
    Add-Log " - Статус:    Не активирована (Ключ продукта не найден)" "Red"
}

# 4. Наличие Microsoft Office и его активация
Add-Log "`n Microsoft Office:" "Yellow"
$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$officeApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
              Where-Object { $_.DisplayName -match "Microsoft Office|Microsoft 365" -and $_.DisplayName -notmatch "MUI|Proof|Language|Update" } |
              Select-Object -ExpandProperty DisplayName -Unique

if ($officeApps) {
    foreach ($app in $officeApps) {
        Add-Log " - Установлен: $app"
    }
    
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
            Add-Log " - Лицензия ($($lic.Name)): $offStatus" $offColor
        }
    } else {
        Add-Log " - Статус активации: Ключ не найден (Возможно, Office не активирован или используется подписка через аккаунт)" "DarkYellow"
    }
} else {
    Add-Log " - Microsoft Office не найден на этом ПК." "Gray"
}

# 5. Список всех установленных программ
Add-Log "`n Все установленные программы:" "Yellow"
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
    Add-Log " - $prog"
}

# 6. Ввод пользовательского имени/заметки и сохранение файла
Write-Host "`n=============================================" -ForegroundColor Cyan
$customName = Read-Host "Введите ваше обозначение для этого ПК (например, Бухгалтерия_Иванов)"

# Очищаем введенное имя от запрещенных в Windows символов для имени файла (\ / : * ? " < > |)
$safeCustomName = ($customName -replace '[\\/:*?"<>|]', '_').Trim()
if ([string]::IsNullOrWhiteSpace($safeCustomName)) {
    $safeCustomName = "БезИмени"
}

# Добавляем заметку в конец отчета
Add-Log "`n============================================="
Add-Log "Примечание / Пользовательское имя ПК: $customName"

# Формируем путь для сохранения рядом со скриптом
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$fileName = "${safeCustomName}_${pcName}.txt"
$filePath = Join-Path -Path $scriptDir -ChildPath $fileName

# Сохраняем файл в UTF-8
$report | Out-File -FilePath $filePath -Encoding UTF8

Write-Host "`nОтчет успешно сохранен в файл:" -ForegroundColor Green
Write-Host $filePath -ForegroundColor White
Read-Host "`nНажмите Enter для выхода"
