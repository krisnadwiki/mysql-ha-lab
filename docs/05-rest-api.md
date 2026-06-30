# REST API

## Gambaran Umum

REST API dibangun menggunakan **FastAPI** sebagai simulasi aplikasi produksi yang terhubung ke MySQL InnoDB Cluster melalui MySQL Router.

**Prinsip utama:** API **tidak pernah** terhubung langsung ke mysql1, mysql2, atau mysql3. Semua koneksi melalui MySQL Router.

---

## Struktur API

```
api/
├── Dockerfile          # Container image definition
├── requirements.txt    # Python dependencies
├── main.py             # FastAPI app + lifespan + health check
├── database.py         # SQLAlchemy engine + session factory
├── models.py           # ORM models (tabel patients)
├── schemas.py          # Pydantic schemas (request/response)
└── routers/
    ├── __init__.py
    └── patients.py     # Endpoint CRUD /patients
```

---

## Konfigurasi Database

Koneksi database dikonfigurasi melalui environment variable:

| Variable | Default | Keterangan |
|---|---|---|
| `DB_HOST` | `mysql-router` | Host MySQL Router |
| `DB_RW_PORT` | `6446` | Port Read/Write Router |
| `DB_NAME` | `labdb` | Nama database |
| `DB_USER` | `admin` | Username |
| `DB_PASSWORD` | `adminpassword` | Password |

### Connection String
```
mysql+mysqlconnector://admin:adminpassword@mysql-router:6446/labdb
```

### Mengapa `pool_pre_ping=True`?
Parameter ini sangat penting untuk HA:
- Sebelum menggunakan koneksi dari pool, SQLAlchemy mengirim `SELECT 1`
- Jika koneksi sudah mati (akibat failover), koneksi baru dibuat otomatis
- Ini memastikan API tetap berjalan setelah failover

---

## Endpoint

### `GET /patients`
Mengambil semua data pasien.

```bash
curl -X GET "http://localhost:8000/patients" -H "accept: application/json"
```

**Response (200):**
```json
[
  {"id": 1, "name": "Budi Santoso", "created_at": "2025-01-01T10:00:00"},
  {"id": 2, "name": "Siti Rahayu", "created_at": "2025-01-01T10:01:00"}
]
```

---

### `GET /patients/{id}`
Mengambil satu pasien berdasarkan ID.

```bash
curl -X GET "http://localhost:8000/patients/1" -H "accept: application/json"
```

**Response (200):**
```json
{"id": 1, "name": "Budi Santoso", "created_at": "2025-01-01T10:00:00"}
```

**Response (404):**
```json
{"detail": "Pasien dengan ID 99 tidak ditemukan."}
```

---

### `POST /patients`
Membuat pasien baru.

```bash
curl -X POST "http://localhost:8000/patients" \
  -H "Content-Type: application/json" \
  -d '{"name": "Budi Santoso"}'
```

**Response (201):**
```json
{"id": 1, "name": "Budi Santoso", "created_at": "2025-01-01T10:00:00"}
```

---

### `DELETE /patients/{id}`
Menghapus pasien berdasarkan ID.

```bash
curl -X DELETE "http://localhost:8000/patients/1"
```

**Response (204):** No Content

---

### `GET /health`
Health check status API dan koneksi database.

```bash
curl http://localhost:8000/health
```

**Response (200):**
```json
{
  "status": "ok",
  "api_version": "1.0.0",
  "database": {
    "status": "connected",
    "host": "mysql-router",
    "port": "6446",
    "note": "Koneksi melalui MySQL Router (HA endpoint)"
  }
}
```

---

## Swagger UI

Swagger UI tersedia di: **http://localhost:8000/docs**

Fitur:
- Lihat semua endpoint beserta dokumentasinya
- Test endpoint langsung dari browser (tanpa curl)
- Lihat schema request dan response

ReDoc tersedia di: **http://localhost:8000/redoc**

---

## Environment Variable

Atur di file `.env` atau `docker-compose.yml`:

```env
DB_HOST=mysql-router
DB_RW_PORT=6446
DB_NAME=labdb
DB_USER=admin
DB_PASSWORD=adminpassword
API_PORT=8000
```

---

## Database Auto-Init

Saat API pertama kali dijalankan, `main.py` secara otomatis:
1. Membuat database `labdb` jika belum ada
2. Membuat tabel `patients` jika belum ada

Tidak perlu menjalankan migrasi secara manual.

---

## Verifikasi

1. **Cek container berjalan:**
   ```bash
   docker compose ps api
   ```

2. **Cek health:**
   ```bash
   curl http://localhost:8000/health
   ```

3. **Buka Swagger:**
   ```
   http://localhost:8000/docs
   ```

4. **Verifikasi koneksi melalui Router (bukan langsung ke mysql1):**
   - Lihat di health response: `"host": "mysql-router"`
   - API tidak boleh terhubung langsung ke `mysql1`
