# Troubleshooting Guide — Milestone 9

Panduan penyelesaian masalah umum dalam mysql-ha-lab.

---

## 1. Cluster Tidak Terbentuk

### Gejala
- `dba.create_cluster()` gagal dengan error
- Output script `02-create-cluster.sh` menunjukkan error

### Penyebab Umum
- `configureInstance()` belum dijalankan
- GTID belum aktif di semua node
- Admin user belum dibuat
- Container belum `healthy` saat script dijalankan

### Langkah Penyelesaian

```bash
# 1. Cek status semua container
docker compose ps

# 2. Pastikan semua container berstatus healthy
# Jika masih starting, tunggu dan cek log
docker compose logs mysql1
docker compose logs mysql2
docker compose logs mysql3

# 3. Verifikasi GTID aktif di semua node
docker exec mysql1 mysql -u root -prootpassword \
  -e "SHOW VARIABLES LIKE 'gtid_mode';"

# 4. Jalankan ulang konfigurasi instance
./scripts/01-configure-instances.sh

# 5. Coba buat cluster kembali
./scripts/02-create-cluster.sh
```

### Cara Verifikasi

```bash
./scripts/04-verify-cluster.sh
# Output harus menunjukkan 1 PRIMARY + 2 SECONDARY, semua ONLINE
```

---

## 2. Router Gagal Bootstrap

### Gejala
- Container `mysql-router` status `unhealthy` atau `exiting`
- Log menunjukkan: `Error connecting to metadata server`

### Penyebab Umum
- InnoDB Cluster belum terbentuk saat router bootstrap
- Admin user credentials tidak cocok
- mysql1 belum sepenuhnya siap

### Langkah Penyelesaian

```bash
# 1. Cek log router
docker compose logs mysql-router

# 2. Pastikan cluster sudah terbentuk
./scripts/04-verify-cluster.sh

# 3. Bootstrap ulang secara manual
./scripts/03-bootstrap-router.sh

# 4. Jika masih gagal, rebuild container router
docker compose rm -f mysql-router
docker compose up -d mysql-router
```

### Cara Verifikasi

```bash
# Test koneksi via router
mysql -u admin -padminpassword -h 127.0.0.1 -P 6446 \
  -e "SELECT @@hostname;"
```

---

## 3. Node OFFLINE

### Gejala
- `cluster.status()` menampilkan node dengan status `OFFLINE`
- API masih berjalan (jika node OFFLINE bukan Primary)

### Penyebab Umum
- Container di-stop secara manual
- Container crash
- Network partition

### Langkah Penyelesaian

```bash
# 1. Start kembali container
docker start mysql2   # sesuaikan dengan node yang OFFLINE

# 2. Tunggu beberapa saat
sleep 30

# 3. Cek status
./scripts/04-verify-cluster.sh

# 4. Jika node tidak mau rejoin otomatis, lakukan rejoin manual
mysqlsh --no-wizard \
  --uri "admin:adminpassword@127.0.0.1:PORT_PRIMARY" \
  --py \
  --execute "
cluster = dba.get_cluster()
cluster.rejoin_instance('admin:adminpassword@mysql2:3306', {
    'interactive': False
})
"
```

### Cara Verifikasi

```bash
./scripts/04-verify-cluster.sh
# Node harus kembali ONLINE dan SECONDARY
```

---

## 4. Node ERROR

### Gejala
- `cluster.status()` menampilkan node dengan status `ERROR`
- Log menunjukkan replication error

### Penyebab Umum
- Data divergen (split-brain scenario)
- Error replikasi yang tidak bisa di-resolve otomatis

### Langkah Penyelesaian

```bash
# 1. Cek log node yang ERROR
docker compose logs mysql2

# 2. Coba resync menggunakan clone
mysqlsh --no-wizard \
  --uri "admin:adminpassword@127.0.0.1:PORT_PRIMARY" \
  --py \
  --execute "
cluster = dba.get_cluster()
cluster.rescan()
cluster.rejoin_instance('admin:adminpassword@mysql2:3306', {
    'recoveryMethod': 'clone',
    'interactive': False
})
"

# 3. Jika masih gagal, remove dan add kembali instance
mysqlsh --no-wizard \
  --uri "admin:adminpassword@127.0.0.1:PORT_PRIMARY" \
  --py \
  --execute "
cluster = dba.get_cluster()
cluster.remove_instance('admin:adminpassword@mysql2:3306', {
    'force': True,
    'interactive': False
})
cluster.add_instance('admin:adminpassword@mysql2:3306', {
    'recoveryMethod': 'clone',
    'interactive': False,
    'waitRecovery': 3
})
"
```

### Cara Verifikasi

```bash
./scripts/04-verify-cluster.sh
```

---

## 5. API Gagal Koneksi ke Database

### Gejala
- `GET /health` mengembalikan `"status": "error: ..."`
- Log API menampilkan `Connection refused` atau `Lost connection`

### Penyebab Umum
- MySQL Router belum siap / crash
- InnoDB Cluster tidak memiliki quorum
- Environment variable DB salah

### Langkah Penyelesaian

```bash
# 1. Cek log API
docker compose logs api

# 2. Cek health router
docker compose ps mysql-router

# 3. Test koneksi manual ke router
mysql -u admin -padminpassword -h 127.0.0.1 -P 6446 -e "SELECT 1;"

# 4. Jika router masalah, restart
docker compose restart mysql-router
sleep 15

# 5. Restart API setelah router kembali normal
docker compose restart api

# 6. Verifikasi environment variable
docker exec api env | grep DB_
```

### Cara Verifikasi

```bash
curl http://localhost:8000/health
# Expected: {"status": "ok", "database": {"status": "connected"}}
```

---

## 6. Docker Volume Error

### Gejala
- Error saat `docker compose up`: `cannot create volume`
- Data hilang setelah container di-recreate

### Penyebab Umum
- Volume sudah ada dari sesi sebelumnya dengan data korup
- Permission issue

### Langkah Penyelesaian

```bash
# 1. Cek semua volume
docker volume ls | grep mysql

# 2. Stop semua container
docker compose down

# 3. HAPUS volume (DATA AKAN HILANG - hanya untuk reset total)
docker volume rm mysql1-data mysql2-data mysql3-data router-data

# 4. Buat ulang semua
docker compose up -d

# 5. Konfigurasi ulang cluster dari awal
./scripts/01-configure-instances.sh
./scripts/02-create-cluster.sh
```

> ⚠️ **PERINGATAN:** Menghapus volume berarti menghapus semua data MySQL!

### Cara Verifikasi

```bash
docker volume ls | grep mysql
# Keempat volume harus ada dan berstatus aktif
```

---

## 7. Network Error

### Gejala
- Container tidak bisa saling berkomunikasi via hostname
- `docker exec mysql1 ping mysql2` gagal

### Penyebab Umum
- Network `mysql-ha-net` belum dibuat
- Container di-recreate tanpa network yang benar

### Langkah Penyelesaian

```bash
# 1. Cek network Docker
docker network ls | grep mysql-ha-net

# 2. Jika tidak ada, recreate
docker compose down
docker compose up -d

# 3. Verifikasi semua container di network yang sama
docker network inspect mysql-ha-net

# 4. Test DNS antar container
docker exec mysql1 ping -c 3 mysql2
docker exec mysql1 ping -c 3 mysql3
docker exec mysql1 ping -c 3 mysql-router
```

### Cara Verifikasi

```bash
docker network inspect mysql-ha-net
# Semua container (mysql1, mysql2, mysql3, mysql-router, api)
# harus terdaftar di bagian "Containers"
```

---

## Quick Diagnostic Command

Gunakan perintah ini untuk diagnosa cepat:

```powershell
echo "=== Container Status ===" ; docker compose ps
echo ""
echo "=== Router Logs (last 10 lines) ===" ; docker logs mysql-router --tail 10
echo ""
echo "=== Cluster Status ==="
docker exec mysql1 mysqlsh --no-wizard --uri "admin:adminpassword@mysql1:3306" `
  --py --execute "import json; c=dba.get_cluster(); print(json.dumps(c.status(), indent=2, default=str))" 2>&1
echo ""
echo "=== Network ===" ; docker network inspect mysql-ha-net --format="{{range .Containers}}{{.Name}} {{end}}"
echo ""
echo "=== Volumes ===" ; docker volume ls | Select-String mysql
```

---

## 8. Metadata Already Exists

### Gejala

```
Unable to create cluster. Metadata schema already exists.
```

Error ini muncul saat `setup-cluster-windows.ps1` (atau `02-create-cluster.sh`) dijalankan
pada instance yang pernah membuat cluster sebelumnya.

### Penyebab

Script setup dijalankan lebih dari sekali tanpa menghapus volume terlebih dahulu.
Metadata cluster (`mysql_innodb_cluster_metadata`) masih tersimpan di volume MySQL.

### Solusi

**Opsi 1 (Direkomendasikan):** Gunakan `setup-cluster-windows.ps1` versi terbaru.

Script ini secara otomatis mendeteksi metadata yang ada dan melakukan `dba.get_cluster()`
alih-alih `dba.create_cluster()`. Tidak perlu intervensi manual.

```powershell
.\scripts\setup-cluster-windows.ps1
```

**Opsi 2:** Jika cluster masih aktif, cukup ambil referensinya:

```powershell
docker exec mysql1 mysqlsh --no-wizard `
  --uri "admin:adminpassword@mysql1:3306" `
  --py --execute "import json; c=dba.get_cluster(); print(json.dumps(c.status(), indent=2, default=str))"
```

**Opsi 3:** Jika ingin reset total, hapus semua volume:

```powershell
docker compose down -v
# Kemudian lakukan First Time Setup dari awal
```

> ⚠️ Opsi 3 akan menghapus semua data MySQL.

---

## 9. Group Replication OFFLINE

### Gejala

```
dba.get_cluster() gagal — Group Replication tidak aktif
performance_schema.replication_group_members menunjukkan OFFLINE
```

### Penyebab

Semua node MySQL restart bersamaan (misalnya karena komputer direboot).
Dalam kondisi ini, Group Replication tidak bisa otomatis resume karena
tidak ada node yang menjadi "seed" untuk cluster.

### Recovery

**Opsi 1 (Otomatis):** Jalankan script setup — script akan mendeteksi GR OFFLINE
dan memanggil `rebootClusterFromCompleteOutage()` secara otomatis:

```powershell
.\scripts\setup-cluster-windows.ps1
```

**Opsi 2 (Manual):** Reboot cluster secara manual via MySQL Shell:

```powershell
docker exec mysql1 mysqlsh --no-wizard `
  --uri "admin:adminpassword@mysql1:3306" `
  --py --execute "dba.reboot_cluster_from_complete_outage('myCluster', {'interactive': False})"
```

**Opsi 3:** Jika reboot gagal (misalnya data divergen), lakukan reset total:

```powershell
docker compose down -v
# Kemudian First Time Setup dari awal
```

### Cara Verifikasi

```powershell
docker exec mysql1 mysql -uadmin -padminpassword `
  -e "SELECT MEMBER_HOST, MEMBER_STATE FROM performance_schema.replication_group_members;"
# Semua node harus ONLINE
```

---

## 10. Router: Waiting for Cluster Instances

### Gejala

Log `mysql-router` menampilkan:
```
[Entrypoint] Successfully contacted mysql server at mysql1:3306. Checking for cluster state.
[Entrypoint] ERROR: Can not connect to database. Exiting.
```

Container `mysql-router` status `unhealthy` atau `exited`.

### Penyebab

MySQL Router mencoba bootstrap sebelum InnoDB Cluster terbentuk.
Router membutuhkan metadata cluster (`mysql_innodb_cluster_metadata`) untuk dapat berjalan.
Jika `setup-cluster-windows.ps1` belum dijalankan, metadata belum ada.

### Solusi

```powershell
# 1. Pastikan cluster sudah terbentuk dahulu
.\scripts\setup-cluster-windows.ps1

# 2. Atau verifikasi cluster manual, lalu restart router
docker exec mysql1 mysqlsh --no-wizard `
  --uri "admin:adminpassword@mysql1:3306" `
  --py --execute "print(dba.get_cluster().status()['defaultReplicaSet']['statusText'])"

# Jika cluster ONLINE, restart router
docker compose restart mysql-router
```

### Cara Verifikasi

```powershell
# Cek log router
docker logs mysql-router --tail 20

# Probe port 6446
.\scripts\wait-for-router.ps1 -TimeoutSec 30
```

---

## 11. API: Cannot Connect mysql-router:6446

### Gejala

- `GET /health` mengembalikan `500 Internal Server Error`
- Log API: `ProgrammingError: 1049 (42000): Unknown database 'labdb'`
- Log API: `OperationalError: Can't connect to MySQL server on 'mysql-router'`

### Penyebab Umum

| Penyebab | Indikator |
|---|---|
| Database `labdb` belum dibuat | Error `Unknown database 'labdb'` |
| Router belum healthy | `docker compose ps` menunjukkan router `unhealthy` |
| Cluster belum ada | Router log: `Can not connect to database` |
| Credentials salah | Error `Access denied` |

### Solusi

**Jika error `Unknown database 'labdb'`:**

```powershell
# Buat database manual
docker exec mysql1 mysql -uroot -prootpassword `
  -e "CREATE DATABASE IF NOT EXISTS labdb; GRANT ALL PRIVILEGES ON labdb.* TO 'admin'@'%'; FLUSH PRIVILEGES;"

# Restart API
docker compose restart api
```

**Jika router belum healthy:**

```powershell
# Jalankan setup script (idempotent, aman dijalankan ulang)
.\scripts\setup-cluster-windows.ps1
```

**Verifikasi environment API:**

```powershell
docker exec api env | Select-String "DB_"
# Harus menampilkan: DB_HOST=mysql-router, DB_RW_PORT=6446, DB_NAME=labdb
```

### Cara Verifikasi

```powershell
curl http://localhost:8000/health
# Expected: {"status": "ok", "database": {"status": "connected"}}
```
