# =============================================================
# wait-for-router.ps1
# Probe TCP ke MySQL Router port 6446 hingga siap
# =============================================================
#
# Digunakan sebelum API dijalankan untuk memastikan Router
# sudah siap menerima koneksi.
#
# Cara menjalankan:
#   .\scripts\wait-for-router.ps1
#   .\scripts\wait-for-router.ps1 -Host mysql-router -Port 6446 -TimeoutSec 90
# =============================================================

param(
    [string]$RouterHost = "127.0.0.1",
    [int]$Port = 6446,
    [int]$TimeoutSec = 60,
    [int]$IntervalSec = 5
)

$start = Get-Date
$deadline = $start.AddSeconds($TimeoutSec)

Write-Host "Menunggu MySQL Router di $RouterHost`:$Port (timeout: ${TimeoutSec}s)..." -ForegroundColor Gray

while ((Get-Date) -lt $deadline) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($RouterHost, $Port, $null, $null)
        $waited = $connect.AsyncWaitHandle.WaitOne(2000, $false)

        if ($waited -and $tcp.Connected) {
            $tcp.Close()
            $elapsed = [int]((Get-Date) - $start).TotalSeconds
            Write-Host "  [OK] Router $RouterHost`:$Port siap (${elapsed}s)." -ForegroundColor Green
            exit 0
        }
        $tcp.Close()
    } catch {
        # Port belum terbuka, lanjut retry
    }

    $remaining = [int]($deadline - (Get-Date)).TotalSeconds
    Write-Host "  [WAIT] Router belum siap... (sisa ${remaining}s)" -ForegroundColor DarkYellow
    Start-Sleep -Seconds $IntervalSec
}

Write-Host "  [TIMEOUT] Router $RouterHost`:$Port tidak siap dalam ${TimeoutSec}s." -ForegroundColor Red
Write-Host "  Cek log: docker logs mysql-router" -ForegroundColor Gray
exit 1
