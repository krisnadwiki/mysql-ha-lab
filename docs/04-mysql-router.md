# MySQL Router

## Fungsi MySQL Router

**MySQL Router** adalah lightweight middleware yang berfungsi sebagai **transparent proxy** antara aplikasi dan MySQL InnoDB Cluster.

**Manfaat utama:**
- Aplikasi hanya perlu mengenal **satu endpoint** (MySQL Router)
- Router yang tahu siapa Primary saat ini
- Failover bersifat **transparan** — aplikasi tidak perlu konfigurasi ulang

---

## Cara Kerja Routing

```
Aplikasi → MySQL Router → Primary / Secondary
```

MySQL Router menyediakan **dua jenis port**:

| Port | Jenis | Keterangan |
|---|---|---|
| **6446** | Read/Write | Selalu diarahkan ke **Primary** |
| **6447** | Read Only | Diarahkan ke **Secondary** (round-robin) |

**Lab ini menggunakan port 6446 (RW)** untuk semua operasi API agar lebih sederhana.

---

## Cara Mendeteksi Primary

MySQL Router secara aktif **memonitor** status cluster:

1. Saat bootstrap, Router terhubung ke cluster dan mendapatkan metadata topology
2. Router menyimpan informasi siapa Primary saat ini
3. Setiap beberapa detik, Router melakukan **health check** ke semua node
4. Jika Primary berubah (failover), Router mendeteksi perubahan dan meng-update routing

```
MySQL Router ──health check──► mysql1 (Primary)  ✓
              ──health check──► mysql2 (Secondary) ✓
              ──health check──► mysql3 (Secondary) ✓
```

---

## Cara Kerja Failover

```
Kondisi: mysql1 (Primary) mati

1. Router health check: mysql1 tidak responsif
        ↓
2. Router menandai mysql1 sebagai OFFLINE
        ↓
3. Group Replication memilih Primary baru (misalnya mysql2)
        ↓
4. Router mendapatkan informasi Primary baru dari metadata cluster
        ↓
5. Koneksi baru dari aplikasi diarahkan ke mysql2
        ↓
6. Aplikasi tetap berjalan tanpa perubahan konfigurasi
```

**Waktu failover:** biasanya 5–30 detik (tergantung konfigurasi health check interval).

---

## Bootstrap MySQL Router

Bootstrap adalah proses menghubungkan MySQL Router ke InnoDB Cluster untuk pertama kali.

Pada lab ini, **bootstrap dilakukan otomatis** saat container `mysql-router` dijalankan via environment variable Docker:

```yaml
# docker-compose.yml
mysql-router:
  environment:
    MYSQL_HOST: mysql1
    MYSQL_PORT: 3306
    MYSQL_USER: admin
    MYSQL_PASSWORD: adminpassword
    MYSQL_INNODB_CLUSTER_MEMBERS: 3
```

### Bootstrap Manual (jika otomatis gagal)
```bash
./scripts/03-bootstrap-router.sh
```

Atau langsung di dalam container:
```bash
docker exec mysql-router \
  mysqlrouter \
  --bootstrap admin:adminpassword@mysql1:3306 \
  --conf-use-sockets \
  --user=mysqlrouter \
  --conf-base-port=6446 \
  --force
```

---

## Verifikasi Router

### Cek status container
```bash
docker compose ps mysql-router
```

### Test koneksi RW (Read/Write)
```bash
mysql -u admin -p -h 127.0.0.1 -P 6446
mysql> SELECT @@hostname;
# Harus menampilkan hostname Primary (mysql1 pada awalnya)
```

### Test koneksi RO (Read Only)
```bash
mysql -u admin -p -h 127.0.0.1 -P 6447
mysql> SELECT @@hostname;
# Akan bergantian antara mysql2 dan mysql3 (round-robin)
```

### Cek Router dapat mendeteksi Primary
```bash
mysql -u admin -p -h 127.0.0.1 -P 6446
mysql> SELECT * FROM performance_schema.replication_group_members;
```

---

## Konfigurasi Router (Setelah Bootstrap)

File konfigurasi router tersimpan di volume `router-data`:
```
/var/lib/mysqlrouter/mysqlrouter.conf
```

Konten penting:
```ini
[routing:myCluster_rw]
bind_address = 0.0.0.0
bind_port    = 6446
destinations = metadata-cache://myCluster/?role=PRIMARY
routing_strategy = first-available

[routing:myCluster_ro]
bind_address = 0.0.0.0
bind_port    = 6447
destinations = metadata-cache://myCluster/?role=SECONDARY
routing_strategy = round-robin
```
