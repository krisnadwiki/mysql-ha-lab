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

```bash
echo "=== Container Status ===" && docker compose ps
echo ""
echo "=== Container Logs (last 20 lines) ===" && docker compose logs --tail=20
echo ""
echo "=== Network ===" && docker network inspect mysql-ha-net --format='{{range .Containers}}{{.Name}} {{end}}'
echo ""
echo "=== Volumes ===" && docker volume ls | grep mysql
```
