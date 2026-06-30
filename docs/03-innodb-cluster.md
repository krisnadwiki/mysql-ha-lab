# MySQL InnoDB Cluster

## Apa itu InnoDB Cluster?

**MySQL InnoDB Cluster** adalah solusi High Availability resmi dari MySQL yang menggabungkan:

1. **Group Replication** — Replikasi data secara otomatis antar node
2. **MySQL Shell** — Alat administrasi untuk mengelola cluster
3. **MySQL Router** — Load balancer yang mengarahkan koneksi ke Primary

---

## Mengapa `configureInstance()` Diperlukan?

Sebelum sebuah node MySQL dapat bergabung ke InnoDB Cluster, node tersebut harus dikonfigurasi ulang untuk mendukung **Group Replication**.

`dba.configureInstance()` melakukan hal berikut:
- Mengaktifkan parameter yang dibutuhkan (GTID, binlog, dll.)
- Membuat **admin user** khusus untuk cluster
- Merestart MySQL jika ada perubahan konfigurasi yang memerlukan restart

```python
# Contoh di MySQL Shell
dba.configure_instance('root:password@mysql1:3306', {
    'clusterAdmin': 'admin',
    'clusterAdminPassword': 'adminpassword',
    'restart': True,
    'interactive': False
})
```

---

## Group Replication

**Group Replication** adalah mekanisme replikasi berbasis *consensus protocol* (Paxos) yang memungkinkan:

- **Replikasi otomatis**: Data yang di-write ke Primary langsung direplikasi ke semua Secondary
- **Fault tolerance**: Cluster tetap berjalan selama quorum terpenuhi
- **Automatic failover**: Jika Primary mati, Secondary baru dipilih secara otomatis

### Cara kerja:
```
1. Client menulis data ke Primary
2. Primary mengirim transaksi ke semua Secondary via Group Replication protocol
3. Semua node harus setuju (majority vote) sebelum transaksi di-commit
4. Data tersinkronisasi ke semua node
```

---

## Cluster Topology

```
myCluster (Single-Primary Mode)
├── mysql1 (PRIMARY)   → Menangani semua Write
├── mysql2 (SECONDARY) → Replica, siap menjadi Primary
└── mysql3 (SECONDARY) → Replica, siap menjadi Primary
```

**Mode yang digunakan:** `Single-Primary` (satu Primary aktif, dua Secondary)

> Mode lainnya: `Multi-Primary` (semua node bisa menerima write) — tidak digunakan dalam lab ini karena lebih kompleks.

---

## Primary Election

Ketika Primary mati, proses election berjalan secara otomatis:

1. Secondary yang tersisa mendeteksi Primary tidak responsif
2. Group Replication memulai **election** menggunakan algoritma Paxos
3. Node dengan **weight** tertinggi atau paling up-to-date dipilih sebagai Primary baru
4. MySQL Router mendapatkan informasi Primary baru dan meng-update routing

Seluruh proses berlangsung dalam hitungan **detik** (biasanya 5–15 detik).

---

## Quorum

**Quorum** adalah jumlah minimum node yang harus aktif agar cluster dapat beroperasi.

```
Formula: Quorum = (N / 2) + 1
```

| Jumlah Node | Quorum | Node Boleh Mati |
|---|---|---|
| 3 (lab ini) | 2 | 1 |
| 5 | 3 | 2 |
| 7 | 4 | 3 |

> **Lab ini menggunakan 3 node** → quorum = 2 → maksimal 1 node boleh mati.
> Jika 2 node mati bersamaan, cluster akan berhenti menerima write (no quorum).

---

## Langkah-Langkah Pembentukan Cluster

### Prasyarat
- Semua container mysql1, mysql2, mysql3 sudah `healthy`
- Script `01-configure-instances.sh` sudah berhasil dijalankan
- MySQL Shell terinstall di host

### Step 1: Konfigurasi setiap instance
```bash
./scripts/01-configure-instances.sh
```

### Step 2: Buat cluster
```bash
./scripts/02-create-cluster.sh
```

### Step 3: Verifikasi
```bash
./scripts/04-verify-cluster.sh
```

### Output yang Diharapkan
```json
{
  "clusterName": "myCluster",
  "defaultReplicaSet": {
    "name": "default",
    "primary": "mysql1:3306",
    "ssl": "REQUIRED",
    "status": "OK",
    "topology": {
      "mysql1:3306": {
        "address": "mysql1:3306",
        "memberRole": "PRIMARY",
        "status": "ONLINE"
      },
      "mysql2:3306": {
        "address": "mysql2:3306",
        "memberRole": "SECONDARY",
        "status": "ONLINE"
      },
      "mysql3:3306": {
        "address": "mysql3:3306",
        "memberRole": "SECONDARY",
        "status": "ONLINE"
      }
    }
  }
}
```

---

## Perintah MySQL Shell Berguna

```python
# Masuk ke MySQL Shell
mysqlsh admin:password@127.0.0.1:3306

# Cek status cluster
cluster = dba.get_cluster()
cluster.status()

# Lihat topology
cluster.describe()

# Cek cluster menggunakan SQL
SELECT * FROM performance_schema.replication_group_members;
```
