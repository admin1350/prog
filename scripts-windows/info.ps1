# Настройка кодировки для корректного отображения кириллицы
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== СБОР ИНФОРМАЦИИ О СИСТЕМЕ ===" -ForegroundColor Cyan

# 1. Имя компьютера
$pcName = $env:COMPUTERNAME
Write-Host "`n[1] Имя ПК: " -NoNewline -ForegroundColor Yellow
Write-Host $pcName

# 2. Тип подключения и IP-адрес
Write-Host "`n[2] Активные сетевые подключения и IP:" -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

if ($adapters) {
    foreach ($adapter in $adapters) {
        # Получаем IPv4 адрес для активного адаптера
        $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $ip = if ($ipInfo) { $ipInfo.IPAddress } else { "Нет IPv4" }
        
        # Определяем тип подключения (Wi-Fi или Кабель)
        $connType = switch -Wildcard ($adapter.InterfaceDescription) {
            "*Wi-Fi*"    { "Wi-Fi (Беспроводное)" }
            "*Wireless*" { "Wi-Fi (Беспроводное)" }
            "*802.11*"   { "Wi-Fi (Беспроводное)" }
            default      { "Ethernet (Кабель) / Другое" }
        }

        Write-Host " - Интерфейс: $($adapter.Name)"
        Write-Host "   Тип:       $connType ($($adapter.InterfaceDescription))"
        Write-Host "   IP-адрес:  $ip"
    }
} else {
    Write-Host " - Активных подключений не найдено." -ForegroundColor Red
}

# 3. Список установленных программ
Write-Host "`n[3] Установленные программы (загрузка...):" -ForegroundColor Yellow

# Читаем ветки реестра для 64-битных и 32-битных приложений
$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$programs = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -ne $null } | 
            Select-Object -ExpandProperty DisplayName -Unique | 
            Sort-Object

foreach ($prog in $programs) {
    Write-Host " - $prog"
}

Write-Host "`n=== ГОТОВО ===" -ForegroundColor Cyan
Read-Host "Нажмите Enter для выхода"
