$ErrorActionPreference = "Stop"

# ── Load .env ────────────────────────────────────────────────
$envFile = Join-Path (Get-Location) ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "File .env tidak ditemukan! Salin dari .env.example terlebih dahulu."
    exit 1
}

$envVars = @{}
Get-Content $envFile | Where-Object { $_ -match "^\s*[^#].+=." } | ForEach-Object {
    $parts = $_ -split "=", 2
    $envVars[$parts[0].Trim()] = $parts[1].Trim()
}

$ROOT_PASS  = $envVars["MYSQL_ROOT_PASSWORD"]
$ADMIN_USER = $envVars["MYSQL_ADMIN_USER"]
$ADMIN_PASS = $envVars["MYSQL_ADMIN_PASSWORD"]
$CLUSTER    = if ($envVars["CLUSTER_NAME"]) { $envVars["CLUSTER_NAME"] } else { "myCluster" }
$DB_NAME    = if ($envVars["DB_NAME"])      { $envVars["DB_NAME"] }      else { "labdb" }

if (-not $ROOT_PASS -or -not $ADMIN_USER -or -not $ADMIN_PASS) {
    Write-Error "MYSQL_ROOT_PASSWORD / MYSQL_ADMIN_USER / MYSQL_ADMIN_PASSWORD tidak lengkap di .env"
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " mysql-ha-lab - Setup InnoDB Cluster (Windows)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Cluster Name : $CLUSTER"
Write-Host " Admin User   : $ADMIN_USER"
Write-Host " Database     : $DB_NAME"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Helper: jalankan script Python mysqlsh lewat FILE (aman) ──
function Invoke-MysqlshFile {
    param(
        [Parameter(Mandatory)][string]$Container,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$ScriptContent,
        [string]$RemoteName = "mysqlha_step.py"
    )

    $localTemp = Join-Path $env:TEMP "mysqlha_$([guid]::NewGuid().ToString('N')).py"
    # Tulis tanpa BOM, akhiri dengan newline biar aman di-parse mysqlsh
    [System.IO.File]::WriteAllText($localTemp, $ScriptContent, [System.Text.UTF8Encoding]::new($false))

    docker cp $localTemp "${Container}:/tmp/$RemoteName" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $localTemp -ErrorAction SilentlyContinue
        throw "Gagal docker cp ke container $Container"
    }

    docker exec $Container mysqlsh --no-wizard --uri $Uri --py -f "/tmp/$RemoteName" | Out-Host
    $exitCode = $LASTEXITCODE

    docker exec $Container rm -f "/tmp/$RemoteName" | Out-Null
    Remove-Item $localTemp -ErrorAction SilentlyContinue

    return $exitCode
}

# ── Helper: tunggu container docker healthy (polling) ─────────
function Wait-ContainerHealthy {
    param(
        [Parameter(Mandatory)][string]$Container,
        [int]$TimeoutSeconds = 180,
        [int]$IntervalSeconds = 5
    )
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $status = (docker inspect --format='{{.State.Health.Status}}' $Container 2>$null)
        if ($status -eq "healthy") { return $true }
        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
        Write-Host "    ... $Container status: $status (${elapsed}s / ${TimeoutSeconds}s)" -ForegroundColor DarkGray
    }
    return $false
}

# ── STEP 1: Cek semua container running & healthy ─────────────
Write-Host ">>> Step 1: Cek status container MySQL..." -ForegroundColor Yellow
foreach ($c in @("mysql1", "mysql2", "mysql3")) {
    if (Wait-ContainerHealthy -Container $c -TimeoutSeconds 120 -IntervalSeconds 10) {
        Write-Host "  [OK] $c healthy" -ForegroundColor Green
    }
    else {
        Write-Error "  [FAIL] $c tidak healthy setelah menunggu. Cek: docker logs $c"
        exit 1
    }
}

# ── STEP 2: Configure semua instance via MySQL Shell ─────────
Write-Host ""
Write-Host ">>> Step 2: Configure setiap instance (dba.configureInstance)..." -ForegroundColor Yellow
Write-Host "    (Ini membuat user admin dan konfigurasi Group Replication)" -ForegroundColor Gray

$configScriptTemplate = @'
print('  Configuring {0}:3306...')
try:
    dba.configure_instance('root:{1}@localhost:3306', {{
        'clusterAdmin': '{2}',
        'clusterAdminPassword': '{3}',
        'restart': True,
        'interactive': False
    }})
    print('  OK: {0} configured.')
except Exception as e:
    message = str(e).lower()
    if 'already belonging to an innodb cluster' in message:
        print('  SKIP: {0} already belongs to a cluster.')
    elif 'account already exists' in message or 'clusteradminpassword is not allowed' in message:
        print('  SKIP: {0} admin account already exists, assuming instance already configured.')
    else:
        raise

print('Done.')
'@

foreach ($node in @('mysql1', 'mysql2', 'mysql3')) {
    $configScript = $configScriptTemplate -f $node, $ROOT_PASS, $ADMIN_USER, $ADMIN_PASS
    $uri = "root:${ROOT_PASS}@localhost:3306"
    $code = Invoke-MysqlshFile -Container $node -Uri $uri -ScriptContent $configScript
    if ($code -ne 0) {
        Write-Error "Gagal configure_instance pada $node (exit code $code)."
        exit 1
    }
    Write-Host "  Menunggu $node restart (20 detik)..." -ForegroundColor Gray
    Start-Sleep -Seconds 20
}

# ── STEP 3: Buat InnoDB Cluster ──────────────────────────────
Write-Host ""
Write-Host ">>> Step 3: Membuat InnoDB Cluster..." -ForegroundColor Yellow

$clusterScriptTemplate = @'
import time, json

try:
    print('Membuat cluster dari mysql1...')
    cluster = dba.create_cluster('{0}', {{
        'multiPrimary': False,
        'force': False,
        'interactive': False
    }})
    print('OK: Cluster dibuat.')
    time.sleep(5)
except Exception as e:
    if 'already belongs to an innodb cluster' in str(e).lower():
        print('Cluster sudah ada, memakai cluster yang sudah terbentuk.')
        cluster = dba.get_cluster('{0}')
    else:
        raise

print('Menambahkan mysql2...')
try:
    cluster.add_instance('{1}:{2}@mysql2:3306', {{
        'recoveryMethod': 'clone',
        'interactive': False,
        'waitRecovery': 3
    }})
    print('OK: mysql2 bergabung.')
except Exception as e:
    message = str(e).lower()
    if 'already belongs to the cluster' in message or 'already part of this innodb cluster' in message:
        print('SKIP: mysql2 sudah menjadi member cluster.')
    else:
        raise

print('Menambahkan mysql3...')
try:
    cluster.add_instance('{1}:{2}@mysql3:3306', {{
        'recoveryMethod': 'clone',
        'interactive': False,
        'waitRecovery': 3
    }})
    print('OK: mysql3 bergabung.')
except Exception as e:
    message = str(e).lower()
    if 'already belongs to the cluster' in message or 'already part of this innodb cluster' in message:
        print('SKIP: mysql3 sudah menjadi member cluster.')
    else:
        raise

print('')
print('=== Status Cluster ===')
status = cluster.status()
print(json.dumps(status, indent=2, default=str))
'@

$clusterScript = $clusterScriptTemplate -f $CLUSTER, $ADMIN_USER, $ADMIN_PASS
$uri = "${ADMIN_USER}:${ADMIN_PASS}@mysql1:3306"
$code = Invoke-MysqlshFile -Container "mysql1" -Uri $uri -ScriptContent $clusterScript
if ($code -ne 0) {
    Write-Error "Gagal membuat cluster. Periksa output di atas."
    exit 1
}

Write-Host "  InnoDB Cluster berhasil dibentuk!" -ForegroundColor Green

# ── STEP 4: Bootstrap database + tabel aplikasi ──────────────
Write-Host ""
Write-Host ">>> Step 4: Bootstrap database & tabel aplikasi ($DB_NAME)..." -ForegroundColor Yellow
Write-Host "    (Membuat database, tabel 'patients', dan privilege untuk admin)" -ForegroundColor Gray

# Skema tabel 'patients' disesuaikan dengan api/models.py & response
# API: {"id": 1, "name": "...", "created_at": "..."}
$schemaSqlTemplate = @'
CREATE DATABASE IF NOT EXISTS `{0}`;

CREATE TABLE IF NOT EXISTS `{0}`.patients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE USER IF NOT EXISTS '{1}'@'%' IDENTIFIED BY '{2}';
GRANT ALL PRIVILEGES ON `{0}`.* TO '{1}'@'%';
FLUSH PRIVILEGES;
'@
$schemaSql = $schemaSqlTemplate -f $DB_NAME, $ADMIN_USER, $ADMIN_PASS

$localSql = Join-Path $env:TEMP "mysqlha_schema_$([guid]::NewGuid().ToString('N')).sql"
[System.IO.File]::WriteAllText($localSql, $schemaSql, [System.Text.UTF8Encoding]::new($false))

$schemaApplied = $false
foreach ($node in @('mysql1', 'mysql2', 'mysql3')) {
    Write-Host "  Mencoba menerapkan schema via $node..." -ForegroundColor Gray
    docker cp $localSql "${node}:/tmp/schema.sql" | Out-Null

    $output = docker exec -e MYSQL_PWD=$ROOT_PASS $node sh -c "mysql -uroot < /tmp/schema.sql" 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    docker exec $node rm -f /tmp/schema.sql | Out-Null

    if ($ok) {
        Write-Host "  OK: schema diterapkan lewat $node (node ini kemungkinan PRIMARY)." -ForegroundColor Green
        $schemaApplied = $true
        break
    }
    else {
        Write-Host "  [SKIP] $node bukan Primary atau gagal, mencoba node berikutnya..." -ForegroundColor DarkYellow
        Write-Host "    Detail: $output" -ForegroundColor DarkGray
    }
}

Remove-Item $localSql -ErrorAction SilentlyContinue

if (-not $schemaApplied) {
    Write-Error "Gagal menerapkan schema ($DB_NAME + tabel patients) ke SEMUA node. Cek status cluster."
    exit 1
}

# Verifikasi tabel benar-benar ada (tanpa sh -c / nested quotes, langsung ke mysql client)
$verify = docker exec -e MYSQL_PWD=$ROOT_PASS mysql1 mysql -uroot -N -e "SHOW TABLES FROM $DB_NAME LIKE 'patients';" 2>&1
if ($verify -match "patients") {
    Write-Host "  OK: tabel 'patients' terverifikasi ada di database '$DB_NAME'." -ForegroundColor Green
}
else {
    Write-Host "  [WARN] Tidak bisa memverifikasi tabel 'patients' dari mysql1 (mungkin node ini Secondary, cek manual jika perlu)." -ForegroundColor DarkYellow
}

# ── STEP 5: Jalankan mysql-router ─────────────────────────────
Write-Host ""
Write-Host ">>> Step 5: Jalankan mysql-router agar bootstrap ke cluster..." -ForegroundColor Yellow
docker compose up -d mysql-router

if (Wait-ContainerHealthy -Container "mysql-router" -TimeoutSeconds 90 -IntervalSeconds 5) {
    Write-Host "  mysql-router healthy!" -ForegroundColor Green
}
else {
    Write-Host "  [WARN] Router belum healthy. Cek log: docker logs mysql-router" -ForegroundColor DarkYellow
}

# ── STEP 6: Jalankan / restart api ────────────────────────────
Write-Host ""
Write-Host ">>> Step 6: Jalankan API..." -ForegroundColor Yellow
docker compose up -d api

$apiOk = $false
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 5
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 5
        if ($resp.StatusCode -eq 200) { $apiOk = $true; break }
    }
    catch { }
    Write-Host "    ... menunggu API siap ($(($i + 1) * 5)s)..." -ForegroundColor DarkGray
}

if ($apiOk) {
    Write-Host "  API sehat dan merespons di /health." -ForegroundColor Green
}
else {
    Write-Host "  [WARN] API belum merespons /health. Cek log: docker compose logs api" -ForegroundColor DarkYellow
}

# ── HASIL AKHIR ──────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Setup Selesai! Status container:" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
docker compose ps
Write-Host ""
Write-Host " Test API   : curl http://localhost:8000/health"
Write-Host ' Test data  : curl -X POST http://localhost:8000/patients -H "Content-Type: application/json" -d "{""name"": ""Test Patient""}"'
Write-Host " Swagger    : http://localhost:8000/docs"
Write-Host "============================================================" -ForegroundColor Cyan