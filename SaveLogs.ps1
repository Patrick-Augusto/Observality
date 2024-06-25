# Caminho para salvar os logs
$outputFile = "C:\Logs\ServerAccessLogs.txt"

# Verifique e crie o diretório, se necessário
if (-not (Test-Path -Path $outputFile)) {
    New-Item -ItemType Directory -Path (Split-Path -Path $outputFile -Parent) | Out-Null
}

# Data e hora da última verificação
$lastCheckTime = (Get-Date).AddMinutes(-10)  # Ajuste conforme necessário

# Função para coletar eventos
function Collect-Events {
    param (
        [DateTime]$Since,
        [string]$LogName,
        [int[]]$EventIds
    )

    Get-WinEvent -FilterHashtable @{
        LogName = $LogName;
        ID = $EventIds;
        StartTime = $Since
    } -ErrorAction SilentlyContinue | ForEach-Object {
        # Aqui você pode selecionar e formatar as propriedades que deseja do evento
        # Por exemplo, para eventos de logon/logoff:
        $ipAddress = "N/A"
        if ($_.Properties[18] -and $_.Properties[18].Value) {
            $ipAddress = $_.Properties[18].Value
        }

        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated
            EventID = $_.Id
            UserName = $_.Properties[5].Value
            IPAddress = $ipAddress
        }
    }
}

# Loop infinito para coletar logs continuamente
while ($true) {
    try {
        # Coletar eventos de logon e logoff
        $logonEvents = Collect-Events -Since $lastCheckTime -LogName "Security" -EventIds 4624, 4634

        # Atualize a data e hora da última verificação
        $lastCheckTime = Get-Date

        # Verifique se há eventos de logon
        if ($logonEvents.Count -gt 0) {
            Write-Host "Eventos de logon encontrados: $($logonEvents.Count)"
            # Salve os logs no arquivo
            $logonEvents | Format-Table -AutoSize | Out-File -FilePath $outputFile -Encoding utf8 -Append

            Write-Host "Logs salvos em $outputFile"
        } else {
            Write-Host "Nenhum novo evento de logon encontrado."
        }

        # Aguardar um período antes de verificar novamente (por exemplo, 60 segundos)
        Start-Sleep -Seconds 60
    } catch {
        Write-Host "Ocorreu um erro: $_"
        # Aguardar um período antes de tentar novamente em caso de erro
        Start-Sleep -Seconds 60
    }
}