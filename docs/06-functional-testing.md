# Functional Testing — Milestone 6

## Tujuan

Memastikan seluruh fungsi sistem berjalan normal sebelum pengujian HA dilakukan.

---

## Prasyarat

Sebelum menjalankan test ini, pastikan:
- [ ] Semua container berstatus `healthy`: `docker compose ps`
- [ ] InnoDB Cluster terbentuk: `./scripts/04-verify-cluster.sh`
- [ ] MySQL Router berhasil bootstrap
- [ ] Swagger dapat diakses: `http://localhost:8000/docs`

---

## Test 1 — Create Patient

### Via Swagger
1. Buka `http://localhost:8000/docs`
2. Pilih `POST /patients`
3. Klik **Try it out**
4. Isi body:
   ```json
   {"name": "Pasien Pertama"}
   ```
5. Klik **Execute**

**Expected Result:** Status `201 Created`, response berisi data pasien dengan `id` dan `created_at`.

### Via curl
```bash
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Pertama"}'
```

**Expected:**
```json
{"id": 1, "name": "Pasien Pertama", "created_at": "..."}
```

---

## Test 2 — Read Patient

### Baca semua pasien
```bash
curl http://localhost:8000/patients
```

**Expected:** Array berisi semua pasien.

### Baca pasien berdasarkan ID
```bash
curl http://localhost:8000/patients/1
```

**Expected:**
```json
{"id": 1, "name": "Pasien Pertama", "created_at": "..."}
```

### Baca ID yang tidak ada
```bash
curl http://localhost:8000/patients/999
```

**Expected:** `404 Not Found`

---

## Test 3 — Delete Patient

```bash
# Buat data dulu
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Akan Dihapus"}'

# Hapus pasien dengan ID yang baru dibuat (sesuaikan ID)
curl -X DELETE "http://localhost:8000/patients/2"
```

**Expected:** Status `204 No Content`

Verifikasi sudah terhapus:
```bash
curl http://localhost:8000/patients/2
# Expected: 404 Not Found
```

---

## Test 4 — Restart API

```bash
# Restart container API
docker compose restart api

# Tunggu beberapa detik
sleep 10

# Verifikasi API kembali berjalan
curl http://localhost:8000/health
```

**Expected:** Status `ok`, database `connected`

Verifikasi data tetap ada:
```bash
curl http://localhost:8000/patients
# Data harus tetap ada
```

---

## Test 5 — Restart Router

```bash
# Restart container router
docker compose restart mysql-router

# Tunggu beberapa detik untuk router reconnect
sleep 15

# Cek health API
curl http://localhost:8000/health

# Cek data
curl http://localhost:8000/patients
```

**Expected:** Semua endpoint tetap berfungsi setelah router restart.

---

## Test 6 — Restart Database Node

```bash
# Restart satu node (Secondary)
docker restart mysql2

# Tunggu node kembali online
sleep 30

# Cek cluster status
./scripts/04-verify-cluster.sh

# Cek API tetap berjalan
curl http://localhost:8000/patients
```

**Expected:** API tetap berjalan, cluster kembali ke status OK.

---

## Checklist Hasil Test

| Test | Expected | Status |
|---|---|---|
| Create Patient | 201 Created | ⬜ |
| Read All Patients | 200 OK, array data | ⬜ |
| Read by ID | 200 OK, satu data | ⬜ |
| Read ID tidak ada | 404 Not Found | ⬜ |
| Delete Patient | 204 No Content | ⬜ |
| Restart API | API kembali normal | ⬜ |
| Restart Router | API tetap berjalan | ⬜ |
| Restart DB Node | API tetap berjalan | ⬜ |
