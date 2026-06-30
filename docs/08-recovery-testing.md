# Recovery Testing — Milestone 8

## Tujuan

Menguji proses **recovery** setelah node yang mati kembali aktif — memastikan node dapat bergabung kembali ke cluster sebagai Secondary dan data tetap sinkron.

---

## Prasyarat

- [ ] Failover testing (Milestone 7) sudah berhasil
- [ ] Ada minimal satu node yang baru saja di-restart

---

## Skenario Recovery

### Step 1 — Start Kembali Node yang Mati

```bash
# Asumsikan mysql1 masih dalam keadaan mati dari failover test
docker start mysql1

echo "mysql1 dinyalakan. Menunggu proses recovery..."
```

---

### Step 2 — Pantau Proses Sinkronisasi

Proses recovery melibatkan:
1. Node menyala dan terhubung ke network Docker
2. Group Replication mendeteksi node baru
3. Node melakukan **state transfer** (distribusi ulang data) dari anggota lain
4. Node berstatus `RECOVERING` → kemudian `ONLINE`

```bash
# Pantau proses recovery (jalankan beberapa kali)
watch -n 5 'docker exec mysql1 mysql -u root -prootpassword \
  -e "SELECT MEMBER_HOST, MEMBER_STATE FROM performance_schema.replication_group_members;"'
```

Tunggu hingga mysql1 berstatus `ONLINE`.

---

### Step 3 — Verifikasi Status Cluster

```bash
./scripts/04-verify-cluster.sh
```

**Expected:**
```
mysql1:3306    | SECONDARY  | ONLINE
mysql2:3306    | PRIMARY    | ONLINE   (atau mysql3)
mysql3:3306    | SECONDARY  | ONLINE
```

Semua 3 node harus `ONLINE`.

---

### Step 4 — Verifikasi Data Sinkron

```bash
# Cek data di node yang baru recovery via API
curl http://localhost:8000/patients

# Cek langsung di mysql1
docker exec -it mysql1 mysql -u root -prootpassword \
  -e "SELECT * FROM labdb.patients;"
```

**Expected:** Data di mysql1 sama persis dengan data di Primary saat ini.

---

### Step 5 — Verifikasi mysql1 Sudah Siap Menerima Replikasi

```bash
# Cek replikasi berjalan di mysql1
docker exec mysql1 mysql -u root -prootpassword \
  -e "SHOW REPLICA STATUS\G"
```

---

### Step 6 — Insert Data Baru dan Verifikasi Replikasi

```bash
# Insert via API (Primary saat ini, misal mysql2)
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pasien Setelah Recovery"}'

# Cek data di mysql1 (harus tersinkronisasi)
docker exec mysql1 mysql -u root -prootpassword \
  -e "SELECT * FROM labdb.patients ORDER BY id DESC LIMIT 5;"
```

**Expected:** Data baru muncul di mysql1 dalam hitungan milidetik.

---

## Checklist Hasil Recovery Test

| Step | Expected | Status |
|---|---|---|
| 1. Start node | Container running | ⬜ |
| 2. Pantau sinkronisasi | Status berubah RECOVERING → ONLINE | ⬜ |
| 3. Verifikasi cluster | Semua node ONLINE | ⬜ |
| 4. Verifikasi data | Data sinkron di semua node | ⬜ |
| 5. Verifikasi replikasi | REPLICA STATUS normal | ⬜ |
| 6. Insert dan cek replikasi | Data baru tersinkronisasi | ⬜ |

---

## Hasil yang Diharapkan

✅ Node kembali ONLINE  
✅ Node menjadi SECONDARY (bukan Primary lagi)  
✅ Data tetap sinkron dengan semua node lain  
✅ Replikasi berjalan normal

---

## Troubleshooting Recovery

### Node tidak mau bergabung (stuck RECOVERING)

```python
# Masuk ke MySQL Shell, terhubung ke Primary
mysqlsh admin:password@127.0.0.1:PORT_PRIMARY

# Coba rejoin manual
cluster = dba.get_cluster()
cluster.rejoin_instance('admin:password@mysql1:3306', {
    'recoveryMethod': 'clone',
    'interactive': False
})
```

### Data tidak sinkron setelah recovery

```python
# Force resync menggunakan clone
cluster.rejoin_instance('admin:password@mysql1:3306', {
    'recoveryMethod': 'clone',
    'interactive': False
})
```

> **Clone** akan mengganti seluruh data di node dengan snapshot dari Primary. Data lama yang tidak sinkron akan ditimpa.
