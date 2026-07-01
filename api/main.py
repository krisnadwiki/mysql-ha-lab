"""
=============================================================
main.py — FastAPI Application Entry Point
=============================================================
REST API untuk mysql-ha-lab
Simulasi aplikasi produksi yang terhubung ke MySQL melalui
MySQL Router (High Availability endpoint)

Akses Swagger UI: http://localhost:8000/docs
Akses ReDoc    : http://localhost:8000/redoc
=============================================================
"""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import engine, Base
from routers import patients


# ── Lifespan: Inisialisasi DB saat startup ───────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifecycle handler:
    - Startup: Buat tabel jika belum ada, buat database jika belum ada
    - Shutdown: Cleanup (tidak ada yang perlu dibersihkan)
    """
    db_name = os.getenv("DB_NAME", "labdb")
    Base.metadata.create_all(bind=engine)
    print(f"✓ Database '{db_name}' dan tabel berhasil diinisialisasi.")

    yield  # Aplikasi berjalan

    # Shutdown
    print("API shutdown.")


# ── Inisialisasi FastAPI ─────────────────────────────────────
app = FastAPI(
    title="mysql-ha-lab API",
    description="""
## mysql-ha-lab REST API

API sederhana sebagai simulasi aplikasi produksi yang terhubung ke
**MySQL InnoDB Cluster** melalui **MySQL Router**.

### Fitur
- CRUD data pasien
- Koneksi ke MySQL melalui MySQL Router (High Availability)
- Auto-reconnect saat terjadi failover

### Arsitektur
```
FastAPI → MySQL Router (port 6446 RW) → InnoDB Cluster
```

### Database
- **Tabel**: `patients`
- **Kolom**: `id`, `name`, `created_at`
    """,
    version="1.0.0",
    contact={
        "name": "mysql-ha-lab",
        "url": "https://github.com/krisnadwiki/mysql-ha-lab",
    },
    license_info={
        "name": "MIT",
    },
    lifespan=lifespan,
)

# ── CORS ─────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────────
app.include_router(patients.router)


# ── Health Check ─────────────────────────────────────────────
@app.get(
    "/health",
    tags=["health"],
    summary="Health check",
    description="Cek status API dan koneksi database.",
)
def health_check():
    """
    Health check endpoint.

    Mengembalikan status API dan koneksi ke MySQL Router.
    Digunakan oleh Docker healthcheck.
    """
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_status = "connected"
        db_host = os.getenv("DB_HOST", "mysql-router")
        db_port = os.getenv("DB_RW_PORT", "6446")
    except Exception as e:
        db_status = f"error: {str(e)}"
        db_host = os.getenv("DB_HOST", "mysql-router")
        db_port = os.getenv("DB_RW_PORT", "6446")

    return {
        "status": "ok",
        "api_version": "1.0.0",
        "database": {
            "status": db_status,
            "host": db_host,
            "port": db_port,
            "note": "Koneksi melalui MySQL Router (HA endpoint)"
        }
    }


# ── Root ─────────────────────────────────────────────────────
@app.get(
    "/",
    tags=["root"],
    summary="Root",
    include_in_schema=False,
)
def root():
    return {
        "message": "mysql-ha-lab API",
        "docs": "/docs",
        "health": "/health",
    }
