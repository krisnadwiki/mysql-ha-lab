"""
=============================================================
database.py — Database Connection
=============================================================
Koneksi ke MySQL melalui MySQL Router (BUKAN langsung ke mysql1)
Ini memastikan High Availability:
  - Jika mysql1 mati, Router otomatis redirect ke Primary baru
  - Aplikasi tidak perlu tahu siapa Primary saat ini
=============================================================
"""

import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# ── Baca environment variable ────────────────────────────────
DB_HOST = os.getenv("DB_HOST", "mysql-router")
DB_PORT = os.getenv("DB_RW_PORT", "6446")
DB_NAME = os.getenv("DB_NAME", "labdb")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "adminpassword")

# ── Connection URL ───────────────────────────────────────────
# mysql+mysqlconnector://<user>:<password>@<host>:<port>/<database>
DATABASE_URL = (
    f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
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
