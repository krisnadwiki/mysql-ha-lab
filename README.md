# mysql-ha-lab

> Lab pembelajaran **MySQL High Availability** menggunakan **MySQL InnoDB Cluster** dan **MySQL Router** berbasis Docker Compose.

![GitHub License](https://img.shields.io/github/license/krisnadwiki/mysql-ha-lab)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql)](https://www.mysql.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.111-009688?logo=fastapi)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python-3.11-yellow?logo=python)](https://www.python.org/)
![Status](https://img.shields.io/badge/Status-Active-success)

---

## 📖 Project Overview

Repository ini adalah **Proof of Concept** implementasi MySQL High Availability yang dirancang sebagai media pembelajaran. Setiap langkah terdokumentasi dengan baik sehingga dapat direplikasi dari awal hingga akhir.

**Komponen utama:**

| Komponen | Teknologi | Fungsi |
|---|---|---|
| Database Cluster | MySQL InnoDB Cluster 8.0 | 3 node HA (1 Primary + 2 Secondary) |
| Load Balancer | MySQL Router 8.0 | Single endpoint untuk aplikasi |
| REST API | FastAPI (Python 3.11) | Simulasi aplikasi produksi |
| Container | Docker Compose | Orkestrasi seluruh service |

---

## 🏗️ Arsitektur
```mermaid
flowchart TB

%% ==========================
%% CLIENT
%% ==========================
subgraph CLIENT["👤 Client"]
    SW["🌐 Swagger UI<br/>localhost:8000/docs"]
    CURL["💻 curl / HTTP Client"]
end

%% ==========================
%% DOCKER NETWORK
%% ==========================
subgraph DOCKER["🐳 Docker Network : mysql-ha-net"]

%% API
subgraph API["🚀 REST API"]
    FASTAPI["FastAPI<br/>api:8000"]
end

%% Router
subgraph ROUTER["⚡ MySQL Router"]
    MYSQLROUTER["MySQL Router"]

    RW["6446<br/>Read / Write"]

    RO["6447<br/>Read Only"]
end

%% Cluster
subgraph CLUSTER["🗄️ MySQL InnoDB Cluster"]

    PRIMARY["👑 mysql1<br/>PRIMARY"]

    SECONDARY1["mysql2<br/>SECONDARY"]

    SECONDARY2["mysql3<br/>SECONDARY"]

end

end

%% ==========================
%% Client Flow
%% ==========================
SW --> FASTAPI
CURL --> FASTAPI

%% ==========================
%% API
%% ==========================
FASTAPI --> MYSQLROUTER

%% ==========================
%% Router
%% ==========================
MYSQLROUTER --> RW
MYSQLROUTER --> RO

%% ==========================
%% Database
%% ==========================
RW --> PRIMARY

RO --> SECONDARY1
RO --> SECONDARY2

%% ==========================
%% Group Replication
%% ==========================
PRIMARY <-. Group Replication .-> SECONDARY1
PRIMARY <-. Group Replication .-> SECONDARY2
SECONDARY1 <-. Group Replication .-> SECONDARY2
```

---

## 📋 Prerequisites

Pastikan tools berikut sudah terinstall sebelum memulai:

| Tool | Versi | Keterangan |
|---|---|---|
| Docker | >= 24.0 | Container runtime |
| Docker Compose | >= 2.20 | Orkestrasi container |
| MySQL Shell | >= 8.0 (Linux/macOS) | Administrasi InnoDB Cluster (untuk script .sh) |
| PowerShell | 5.1+ (Windows) | Menjalankan setup-cluster-windows.ps1 |
| curl / Postman | Any | Testing API (opsional) |

### Cek instalasi
```bash
docker --version
docker compose version
mysqlsh --version
```

Untuk Windows, `mysqlsh` di host bersifat opsional jika menggunakan script:

```powershell
$PSVersionTable.PSVersion
docker --version
docker compose version
```

---

## 📁 Repository Structure

```
mysql-ha-lab/
├── 📄 MILESTONE.md              # Development milestones
├── 📄 README.md                 # Dokumentasi utama (file ini)
├── 📄 LICENSE                   # Lisensi MIT
├── 📄 .env.example              # Template environment variables
├── 📄 .gitignore
├── 📄 docker-compose.yml        # Orkestrasi semua service
│
├── 📁 config/
│   └── mysql/
│       ├── my1.cnf              # Konfigurasi MySQL node 1
│       ├── my2.cnf              # Konfigurasi MySQL node 2
│       └── my3.cnf              # Konfigurasi MySQL node 3
│
├── 📁 scripts/
│   ├── 01-configure-instances.sh   # dba.configureInstance() (Linux/macOS)
│   ├── 02-create-cluster.sh        # createCluster() + addInstance() (Linux/macOS)
│   ├── 03-bootstrap-router.sh      # Bootstrap MySQL Router (Linux/macOS)
│   ├── 04-verify-cluster.sh        # Verifikasi status cluster
│   └── setup-cluster-windows.ps1   # Setup cluster + bootstrap router (Windows)
│
├── 📁 api/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── main.py                  # FastAPI app + health check
│   ├── database.py              # SQLAlchemy engine
│   ├── models.py                # ORM model (patients)
│   ├── schemas.py               # Pydantic schemas
│   └── routers/
│       └── patients.py          # CRUD endpoints
│
└── 📁 docs/
    ├── 01-architecture.md       # Arsitektur sistem
    ├── 02-mysql-nodes.md        # Penjelasan node MySQL
    ├── 03-innodb-cluster.md     # InnoDB Cluster & Group Replication
    ├── 04-mysql-router.md       # MySQL Router
    ├── 05-rest-api.md           # REST API
    ├── 06-functional-testing.md # Functional testing
    ├── 07-failover-testing.md   # Failover testing
    ├── 08-recovery-testing.md   # Recovery testing
    └── 09-troubleshooting.md    # Troubleshooting guide
```

---

## 🚀 Quick Start

### Step 1 — Clone dan Setup Environment

```bash
git clone https://github.com/krisnadwiki/mysql-ha-lab
cd mysql-ha-lab

# Salin template environment
cp .env.example .env

# Edit sesuai kebutuhan (password, dll)
# nano .env   atau   notepad .env
```

Untuk Windows PowerShell:

```powershell
git clone https://github.com/krisnadwiki/mysql-ha-lab
cd mysql-ha-lab

Copy-Item .env.example .env
notepad .env
```

### Step 2 — Jalankan MySQL Nodes Dulu

```bash
docker compose up -d mysql1 mysql2 mysql3

# Tunggu 3 node MySQL healthy (bisa 1-2 menit)
docker compose ps
```

**Expected output minimal:**
```
NAME           STATUS
mysql1         Up X seconds (healthy)
mysql2         Up X seconds (healthy)
mysql3         Up X seconds (healthy)
```
<div class="warning" style="background-color: #fff3cd; border-left: 6px solid #ffc107; padding: 15px; color: #664d03;">
  <strong>⚠️ WARNING:</strong>
  <br>Jangan menjalankan Router maupun API terlebih dahulu.
  <br>Karena InnoDB Cluster belum terbentuk.
</div>


### Step 3 — Konfigurasi InnoDB Cluster

#### Opsi A (Windows)

```powershell
.\scripts\setup-cluster-windows.ps1
```

Script ini akan menjalankan konfigurasi instance, membuat InnoDB Cluster, membuat database aplikasi `labdb` lewat `mysqlsh` root ke `mysql1`, lalu menjalankan `mysql-router` dan `api`.

#### Alur Windows yang dipakai script

Saat menjalankan `setup-cluster-windows.ps1`, urutannya adalah:

1. Start dan cek health `mysql1`, `mysql2`, `mysql3`
2. Configure tiap instance MySQL
3. Bentuk InnoDB Cluster
4. Bootstrap database aplikasi `labdb` dan privilege `admin`
5. Jalankan `mysql-router`
6. Jalankan `api`

Kalau Anda rerun script ini di environment yang sudah pernah dipakai, script akan mencoba memakai cluster yang sudah ada dan melewati member yang sudah tergabung.

#### Opsi B (Linux/macOS)

```bash
# Step 3a: Configure semua instance
chmod +x scripts/*.sh
./scripts/01-configure-instances.sh

# Step 3b: Buat cluster
./scripts/02-create-cluster.sh

# Step 3c: Verifikasi cluster
./scripts/04-verify-cluster.sh
```

### Step 4 — Jalankan Router
Jalankan Router
```bash
docker compose up -d mysql-router
```

**Expected output:**
```
[+] up 4/4
 ✔ Container mysql3       Healthy                                                      
 ✔ Container mysql1       Healthy                                                      
 ✔ Container mysql2       Healthy                                                      
 ✔ Container mysql-router Started   
 ```

### Step 5 — Jalankan REST API

Baru setelah Router healthy.
```bash
docker compose up -d api
```

Jika Anda memakai Windows workflow otomatis, langkah ini sudah dilakukan oleh `setup-cluster-windows.ps1`.

**Expected output:**
```
[+] up 5/5
 ✔ Container mysql1       Healthy                                                      
 ✔ Container mysql3       Healthy                                                      
 ✔ Container mysql2       Healthy                                                      
 ✔ Container mysql-router Healthy                                                      
 ✔ Container api          Started  
 ```
### Step 6 — Verifikasi Akhir

```bash
# Cek status semua service
docker compose ps

# Cek API health
curl.exe http://localhost:8000/health

# Buka Swagger UI
http://localhost:8000/docs
```

**Expected output final:**
```
NAME           STATUS
mysql1         Up X seconds (healthy)
mysql2         Up X seconds (healthy)
mysql3         Up X seconds (healthy)
mysql-router   Up X seconds (healthy)
api            Up X seconds (healthy)
```

---

## 🔌 Port Reference

| Service | Port | Keterangan |
|---|---|---|
| mysql1 | `3306` | MySQL Node 1 (Primary awal) |
| mysql2 | `3307` | MySQL Node 2 |
| mysql3 | `3308` | MySQL Node 3 |
| MySQL Router RW | `6446` | Read/Write → selalu ke Primary |
| MySQL Router RO | `6447` | Read Only → Secondary (round-robin) |
| REST API | `8000` | FastAPI + Swagger UI |

---

## 📡 API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| `GET` | `/patients` | Ambil semua pasien |
| `GET` | `/patients/{id}` | Ambil pasien berdasarkan ID |
| `POST` | `/patients` | Buat pasien baru |
| `DELETE` | `/patients/{id}` | Hapus pasien |
| `GET` | `/health` | Health check API |

**Swagger UI:** http://localhost:8000/docs

---

## 🧪 Testing

### Functional Test
```bash
# Create
curl -X POST http://localhost:8000/patients \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Patient"}'

# Read
curl http://localhost:8000/patients

# Delete
curl -X DELETE http://localhost:8000/patients/1
```

### Failover Test
```bash
# 1. Insert data
curl -X POST http://localhost:8000/patients \
  -H "Content-Type: application/json" \
  -d '{"name": "Before Failover"}'

# 2. Matikan Primary
docker stop mysql1

# 3. Tunggu election (20 detik)
sleep 20

# 4. Insert data (harus tetap berhasil!)
curl -X POST http://localhost:8000/patients \
  -H "Content-Type: application/json" \
  -d '{"name": "After Failover"}'

# 5. Nyalakan kembali
docker start mysql1
```

> 📖 Panduan lengkap: [docs/07-failover-testing.md](docs/07-failover-testing.md)

---

## 📚 Dokumentasi Lengkap

| Dokumen | Keterangan |
|---|---|
| [01-architecture.md](docs/01-architecture.md) | Arsitektur sistem dan diagram |
| [02-mysql-nodes.md](docs/02-mysql-nodes.md) | Penjelasan node MySQL |
| [03-innodb-cluster.md](docs/03-innodb-cluster.md) | InnoDB Cluster & Group Replication |
| [04-mysql-router.md](docs/04-mysql-router.md) | MySQL Router |
| [05-rest-api.md](docs/05-rest-api.md) | REST API |
| [06-functional-testing.md](docs/06-functional-testing.md) | Functional testing |
| [07-failover-testing.md](docs/07-failover-testing.md) | Failover testing |
| [08-recovery-testing.md](docs/08-recovery-testing.md) | Recovery testing |
| [09-troubleshooting.md](docs/09-troubleshooting.md) | Troubleshooting guide |

---

## 🛑 Menghentikan Lab

```bash
# Stop semua container (data tetap tersimpan)
docker compose stop

# Stop dan hapus container (data tetap tersimpan di volume)
docker compose down

# Reset total (HAPUS SEMUA DATA)
docker compose down -v
```

### Catatan Windows

Di PowerShell, gunakan `curl.exe` jika ingin memanggil endpoint HTTP dari command line. Alias `curl` bawaan PowerShell mengarah ke `Invoke-WebRequest`.

---

## ✅ Best Practices

1. **Selalu gunakan MySQL Router sebagai endpoint** — jangan koneksi langsung ke node MySQL
2. **Gunakan `pool_pre_ping=True`** di SQLAlchemy untuk auto-recovery saat failover
3. **Minimal 3 node** untuk quorum yang sehat (toleransi 1 node mati)
4. **Monitor cluster secara berkala** menggunakan `cluster.status()`
5. **Backup data** secara reguler meskipun HA aktif

---

## ⚠️ Production Notes

> Konfigurasi ini dirancang untuk **pembelajaran dan POC**. Untuk production:

- Jalankan node di server/VM terpisah (bukan satu mesin)
- Gunakan SSL/TLS untuk komunikasi antar node
- Konfigurasi `group_replication_member_weight` untuk mengontrol Primary preference
- Setup monitoring (Prometheus + Grafana)
- Konfigurasikan backup otomatis (MySQL Enterprise Backup atau mysqldump + cron)
- Gunakan dedicated network untuk Group Replication traffic

---
## 📄 License
This project is licensed under MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  Built with ❤️ by Krisna Dwiki Aldi <br>
  Copyright © 2026. All rights reserved.
</div>