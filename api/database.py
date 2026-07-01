"""
=============================================================
database.py — Database Connection
=============================================================
Koneksi ke MySQL melalui MySQL Router (BUKAN langsung ke mysql1)
Ini memastikan High Availability:
  - Jika mysql1 mati, Router otomatis redirect ke Primary baru
  - Aplikasi tidak perlu tahu siapa Primary saat ini

Startup Retry:
  Jika Router belum siap saat API start, koneksi di-retry
  sesuai env DB_CONNECT_RETRIES dan DB_CONNECT_INTERVAL.
=============================================================
"""

import os
import time
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# ── Baca environment variable ────────────────────────────────
DB_HOST     = os.getenv("DB_HOST", "mysql-router")
DB_PORT     = os.getenv("DB_RW_PORT", "6446")
DB_NAME     = os.getenv("DB_NAME", "labdb")
DB_USER     = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "adminpassword")

# Retry saat startup jika Router belum siap
DB_CONNECT_RETRIES  = int(os.getenv("DB_CONNECT_RETRIES", "10"))
DB_CONNECT_INTERVAL = int(os.getenv("DB_CONNECT_INTERVAL", "5"))

# ── Connection URL ───────────────────────────────────────────
# mysql+mysqlconnector://<user>:<password>@<host>:<port>/<database>
DATABASE_URL = (
    f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

ADMIN_DATABASE_URL = (
    f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/"
)

# ── SQLAlchemy Engine ────────────────────────────────────────
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,        # Test koneksi sebelum digunakan (penting untuk HA)
    pool_recycle=3600,         # Recycle koneksi setiap 1 jam
    pool_size=5,
    max_overflow=10,
    echo=False,                # Set True untuk debug SQL
)

admin_engine = create_engine(
    ADMIN_DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    pool_size=2,
    max_overflow=5,
    echo=False,
)

# ── Session Factory ──────────────────────────────────────────
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ── Base Class untuk Models ──────────────────────────────────
class Base(DeclarativeBase):
    pass

# ── Dependency untuk FastAPI ─────────────────────────────────
def get_db():
    """
    Dependency injection untuk mendapatkan database session.
    Digunakan di setiap endpoint yang membutuhkan koneksi DB.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ── Startup connection probe dengan retry ────────────────────
def wait_for_db() -> bool:
    """
    Probe koneksi ke database saat startup.
    Retry hingga DB_CONNECT_RETRIES kali dengan jeda DB_CONNECT_INTERVAL detik.
    Return True jika berhasil, False jika timeout.
    """
    for attempt in range(1, DB_CONNECT_RETRIES + 1):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            print(f"✓ Koneksi ke {DB_HOST}:{DB_PORT} berhasil (attempt {attempt}).")
            return True
        except Exception as e:
            print(
                f"  [RETRY {attempt}/{DB_CONNECT_RETRIES}] "
                f"Menunggu MySQL Router di {DB_HOST}:{DB_PORT}... ({e.__class__.__name__})"
            )
            if attempt < DB_CONNECT_RETRIES:
                time.sleep(DB_CONNECT_INTERVAL)
    print(f"✗ Gagal konek ke {DB_HOST}:{DB_PORT} setelah {DB_CONNECT_RETRIES} percobaan.")
    return False


def initialize_database() -> None:
    """
    Buat database dan tabel jika belum ada.

    Fungsi ini menggunakan koneksi admin tanpa menyebut database tujuan,
    supaya startup tetap bisa berjalan pada deployment baru.
    """
    with admin_engine.connect() as conn:
        conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}`"))
        conn.commit()

    Base.metadata.create_all(bind=engine)
