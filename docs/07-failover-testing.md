# Failover Testing — Milestone 7

## Tujuan

Membuktikan bahwa **High Availability berjalan** — jika Primary mati, cluster otomatis memilih Primary baru dan aplikasi tetap berjalan tanpa perubahan konfigurasi.

---

## Prasyarat

- [ ] Functional testing (Milestone 6) sudah berhasil
- [ ] Cluster status OK: `./scripts/04-verify-cluster.sh`
- [ ] Swagger dapat diakses: `http://localhost:8000/docs`

---

## Skenario Failover

### Step 1 — Insert Data Awal

```bash
# Buat beberapa data pasien
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Sebelum Failover 1"}'

curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Sebelum Failover 2"}'

curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Sebelum Failover 3"}'
```

---

### Step 2 — Verifikasi Data Awal

```bash
curl http://localhost:8000/patients
```

**Expected:** 3 data pasien tersedia.

Cek siapa Primary saat ini:
```bash
mysql -u admin -p -h 127.0.0.1 -P 6446 \
  -e "SELECT @@hostname AS current_primary;"
```

---

### Step 3 — Matikan Primary (mysql1)

```bash
# Hentikan container mysql1 (Primary)
docker stop mysql1

echo "mysql1 dimatikan. Menunggu election..."
```

> ⚠️ **Perhatikan:** Setelah perintah ini, akan ada jeda beberapa detik di mana cluster sedang melakukan election.

---

### Step 4 — Tunggu Proses Election

```bash
# Tunggu 20 detik untuk proses election
sleep 20

# Cek status cluster
# Terhubung via port 3307 (mysql2) karena mysql1 mati
mysqlsh --no-wizard \
  --uri "admin:adminpassword@127.0.0.1:3307" \
  --py \
  --execute "
cluster = dba.get_cluster()
import json
print(json.dumps(cluster.status(), indent=2, default=str))
"
```

**Expected:** mysql2 atau mysql3 sekarang berstatus PRIMARY.

---

### Step 5 — Insert Data Setelah Failover

```bash
# API harus tetap berjalan tanpa perubahan konfigurasi
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Setelah Failover"}'
```

**Expected:** Data berhasil dibuat. Ini membuktikan write berhasil ke Primary baru.

---

### Step 6 — Verifikasi Data Konsisten

```bash
curl http://localhost:8000/patients
```

**Expected:**
- 3 data sebelum failover tetap ada
- 1 data baru setelah failover berhasil ditambahkan
- Total: 4 data

---

### Step 7 — Nyalakan Kembali Primary Lama

```bash
# Start kembali mysql1
docker start mysql1

echo "mysql1 dinyalakan. Menunggu sinkronisasi..."
sleep 30
```

---

### Step 8 — Verifikasi mysql1 Kembali sebagai Secondary

```bash
./scripts/04-verify-cluster.sh
```

**Expected:**
- Cluster kembali ke status `OK`
- mysql1 bergabung kembali sebagai **SECONDARY** (bukan Primary lagi)
- Primary saat ini adalah mysql2 atau mysql3

---

## Checklist Hasil Failover Test

| Step | Expected | Status |
|---|---|---|
| 1. Insert data awal | 3 data berhasil dibuat | ⬜ |
| 2. Verifikasi data | 3 data tampil di API | ⬜ |
| 3. Matikan mysql1 | Container stopped | ⬜ |
| 4. Tunggu election | Primary baru terpilih | ⬜ |
| 5. Insert data baru | Data berhasil dibuat via Primary baru | ⬜ |
| 6. Verifikasi konsistensi | Semua data (lama + baru) ada | ⬜ |
| 7. Nyalakan mysql1 | Container running | ⬜ |
| 8. Verifikasi recovery | mysql1 kembali sebagai SECONDARY | ⬜ |

---

## Hasil yang Diharapkan

✅ API tetap berjalan saat Primary mati  
✅ Tidak ada perubahan konfigurasi aplikasi  
✅ Primary berpindah otomatis ke Secondary  
✅ Data tetap konsisten sebelum dan sesudah failover

---

## Catatan Penting

- **Connection error singkat** saat failover bisa terjadi (beberapa detik). Ini normal karena router perlu waktu mendeteksi Primary baru.
- Jika menggunakan `pool_pre_ping=True` (sudah dikonfigurasi di `database.py`), SQLAlchemy akan otomatis retry koneksi.
- **Jangan restart API** selama failover test — ini bukan retry manual, melainkan auto-recovery.
