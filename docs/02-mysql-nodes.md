# MySQL Cluster Nodes

## Gambaran Umum

Lab ini menggunakan **3 instance MySQL** yang berjalan sebagai container Docker terpisah.

| Node | Hostname | Host Port | Peran Awal |
|---|---|---|---|
| mysql1 | mysql1 | 3306 | Primary |
| mysql2 | mysql2 | 3307 | Secondary |
| mysql3 | mysql3 | 3308 | Secondary |

---

## Penjelasan Setiap Node

### mysql1
- **Peran awal**: Primary (node yang menangani semua operasi write)
- **Port**: `3306` (dapat diakses dari host sebagai `127.0.0.1:3306`)
- **Volume**: `mysql1-data` → `/var/lib/mysql`
- **Config**: `config/mysql/my1.cnf`

### mysql2
- **Peran awal**: Secondary (replica dari Primary)
- **Port**: `3307` (dapat diakses dari host sebagai `127.0.0.1:3307`)
- **Volume**: `mysql2-data` → `/var/lib/mysql`
- **Config**: `config/mysql/my2.cnf`

### mysql3
- **Peran awal**: Secondary (replica dari Primary)
- **Port**: `3308` (dapat diakses dari host sebagai `127.0.0.1:3308`)
- **Volume**: `mysql3-data` → `/var/lib/mysql`
- **Config**: `config/mysql/my3.cnf`

---

## Konfigurasi MySQL (my.cnf)

Setiap node memiliki konfigurasi yang **hampir identik** dengan perbedaan:
- `server-id` unik (1, 2, 3)
- `report_host` sesuai hostname container

### Parameter penting:

| Parameter | Nilai | Keterangan |
|---|---|---|
| `server-id` | 1/2/3 | ID unik wajib untuk replikasi |
| `report_host` | mysql1/2/3 | Hostname yang dilaporkan ke cluster |
| `binlog_format` | ROW | Format binary log untuk replikasi |
| `gtid_mode` | ON | GTID wajib untuk InnoDB Cluster |
| `enforce_gtid_consistency` | ON | Konsistensi GTID |
| `log_replica_updates` | ON | Node meneruskan update dari Primary |

---

## Cara Masuk ke Container

```bash
# Masuk ke mysql1
docker exec -it mysql1 bash

# Masuk ke mysql2
docker exec -it mysql2 bash

# Masuk ke mysql3
docker exec -it mysql3 bash
```

---

## Cara Login MySQL

### Via Docker exec (dari dalam container)
```bash
# Login ke mysql1
docker exec -it mysql1 mysql -u root -p

# Login ke mysql2
docker exec -it mysql2 mysql -u root -p

# Login ke mysql3
docker exec -it mysql3 mysql -u root -p
```

### Via Host Port (dari luar container)
```bash
# Login ke mysql1
mysql -u root -p -h 127.0.0.1 -P 3306

# Login ke mysql2
mysql -u root -p -h 127.0.0.1 -P 3307

# Login ke mysql3
mysql -u root -p -h 127.0.0.1 -P 3308
```

### Login menggunakan Admin User
```bash
# Setelah InnoDB Cluster dibentuk, gunakan admin user
mysql -u admin -p -h 127.0.0.1 -P 3306
```

---

## Cara Restart Container

```bash
# Restart satu node
docker restart mysql1

# Restart semua node
docker compose restart mysql1 mysql2 mysql3
```

---

## Verifikasi Data Setelah Restart

```bash
# 1. Restart container
docker restart mysql1

# 2. Tunggu beberapa detik, lalu login
docker exec -it mysql1 mysql -u root -p

# 3. Cek database
mysql> SHOW DATABASES;
mysql> USE labdb;
mysql> SELECT * FROM patients;
# Data harus tetap ada (berkat Docker volume)
```

---

## Healthcheck

Setiap container MySQL dikonfigurasi dengan healthcheck:

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-pPASSWORD"]
  interval: 10s
  timeout: 5s
  retries: 10
  start_period: 60s
```

Cek status healthcheck:
```bash
docker compose ps
# Kolom STATUS harus menunjukkan: healthy
```
