# =============================================================
# setup-cluster-windows.ps1
# Setup InnoDB Cluster via Docker (tanpa MySQL Shell di host)
# Khusus untuk Windows PowerShell
# =============================================================
#
# Script ini menggantikan:
#   01-configure-instances.sh
#   02-create-cluster.sh
#   03-bootstrap-router.sh
#
# Cara menjalankan (dari direktori root project):
#   .\scripts\setup-cluster-windows.ps1
# =============================================================

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

$ROOT_PASS = $envVars["MYSQL_ROOT_PASSWORD"]
$ADMIN_USER = $envVars["MYSQL_ADMIN_USER"]
$ADMIN_PASS = $envVars["MYSQL_ADMIN_PASSWORD"]
$CLUSTER = if ($envVars["CLUSTER_NAME"]) { $envVars["CLUSTER_NAME"] } else { "myCluster" }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " mysql-ha-lab - Setup InnoDB Cluster (Windows)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Cluster Name : $CLUSTER"
Write-Host " Admin User   : $ADMIN_USER"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── STEP 1: Cek semua container running ──────────────────────
Write-Host ">>> Step 1: Cek status container..." -ForegroundColor Yellow
$containers = @("mysql1", "mysql2", "mysql3")
foreach ($c in $containers) {
    $status = docker inspect --format='{{.State.Health.Status}}' $c 2>&1
    if ($status -ne "healthy") {
        Write-Host "  [WARN] $c status: $status - tunggu..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 15
    }
    else {
        Write-Host "  [OK] $c healthy" -ForegroundColor Green
    }
}

# ── STEP 2: Configure semua instance via MySQL Shell ─────────
Write-Host ""
Write-Host ">>> Step 2: Configure setiap instance (dba.configureInstance)..." -ForegroundColor Yellow
Write-Host "    (Ini membuat user admin dan konfigurasi Group Replication)" -ForegroundColor Gray

$configScriptTemplate = @'
import time

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
    else:
        raise

print('Done.')
'@

foreach ($node in @('mysql1', 'mysql2', 'mysql3')) {
    $configScript = $configScriptTemplate -f $node, $ROOT_PASS, $ADMIN_USER, $ADMIN_PASS
    docker exec $node mysqlsh --no-wizard --uri "root:${ROOT_PASS}@localhost:3306" --py --execute $configScript
    Write-Host ""
    Write-Host "  Menunggu $node restart (20 detik)..." -ForegroundColor Gray
    Start-Sleep -Seconds 20
}

# ── STEP 3: Buat InnoDB Cluster ──────────────────────────────
Write-Host ""
Write-Host ">>> Step 3: Membuat InnoDB Cluster..." -ForegroundColor Yellow

$clusterScript = "
import time, json

try:
    print('Membuat cluster dari mysql1...')
    cluster = dba.create_cluster('${CLUSTER}', {
        'multiPrimary': False,
        'force': False,
        'interactive': False
    })
    print('OK: Cluster dibuat.')
    time.sleep(5)
except Exception as e:
    if 'already belongs to an innodb cluster' in str(e).lower():
        print('Cluster sudah ada, memakai cluster yang sudah terbentuk.')
        cluster = dba.get_cluster('${CLUSTER}')
    else:
        raise

print('Menambahkan mysql2...')
try:
    cluster.add_instance('${ADMIN_USER}:${ADMIN_PASS}@mysql2:3306', {
        'recoveryMethod': 'clone',
        'interactive': False,
        'waitRecovery': 3
    })
    print('OK: mysql2 bergabung.')
except Exception as e:
    message = str(e).lower()
    if 'already belongs to the cluster' in message or 'already part of this innodb cluster' in message:
        print('SKIP: mysql2 sudah menjadi member cluster.')
    else:
        raise

print('Menambahkan mysql3...')
try:
    cluster.add_instance('${ADMIN_USER}:${ADMIN_PASS}@mysql3:3306', {
        'recoveryMethod': 'clone',
        'interactive': False,
        'waitRecovery': 3
    })
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
"

docker exec mysql1 mysqlsh --no-wizard --uri "${ADMIN_USER}:${ADMIN_PASS}@mysql1:3306" --py --execute $clusterScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal membuat cluster. Periksa output di atas."
    exit 1
}

Write-Host "  InnoDB Cluster berhasil dibentuk!" -ForegroundColor Green

# ── STEP 4: Bootstrap database aplikasi ─────────────────────
Write-Host ""
Write-Host ">>> Step 4: Bootstrap database aplikasi (labdb)..." -ForegroundColor Yellow

$schemaScript = @"
print('Membuat database labdb dan privilege untuk admin...')
session.run_sql('CREATE DATABASE IF NOT EXISTS labdb')
session.run_sql("GRANT ALL PRIVILEGES ON labdb.* TO '$ADMIN_USER'@'%'")
session.run_sql('FLUSH PRIVILEGES')
print('OK: database labdb siap digunakan.')
"@

docker exec mysql1 mysqlsh --no-wizard --uri "root:${ROOT_PASS}@mysql1:3306" --py --execute $schemaScript
Write-Host "  OK: database labdb siap digunakan." -ForegroundColor Green

# ── STEP 5: Restart mysql-router ─────────────────────────────
Write-Host ""
Write-Host ">>> Step 5: Jalankan mysql-router agar bootstrap ke cluster..." -ForegroundColor Yellow
docker compose up -d mysql-router
Write-Host "  Menunggu router bootstrap (30 detik)..." -ForegroundColor Gray
Start-Sleep -Seconds 30

$routerStatus = docker inspect --format='{{.State.Health.Status}}' mysql-router 2>&1
if ($routerStatus -eq "healthy") {
    Write-Host "  mysql-router healthy!" -ForegroundColor Green
}
else {
    Write-Host "  [WARN] Router status: $routerStatus" -ForegroundColor DarkYellow
    Write-Host "  Cek log: docker logs mysql-router" -ForegroundColor Gray
}

# ── STEP 6: Restart api ──────────────────────────────────────
Write-Host ""
Write-Host ">>> Step 6: Jalankan API..." -ForegroundColor Yellow
docker compose up -d api
Start-Sleep -Seconds 15

# ── HASIL AKHIR ──────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Setup Selesai! Status container:" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
docker compose ps
Write-Host ""
Write-Host " Test API: curl http://localhost:8000/health"
Write-Host " Swagger : http://localhost:8000/docs"
Write-Host "============================================================" -ForegroundColor Cyan
