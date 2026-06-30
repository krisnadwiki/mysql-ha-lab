"""
=============================================================
models.py — SQLAlchemy Models
=============================================================
Definisi tabel database menggunakan SQLAlchemy ORM.

Tabel: patients
Kolom:
  - id         : Primary key, auto increment
  - name       : Nama pasien (required)
  - created_at : Timestamp dibuat (auto)
=============================================================
"""

from datetime import datetime
from sqlalchemy import Integer, String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from database import Base


class Patient(Base):
    """Model untuk tabel patients."""

    __tablename__ = "patients"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
        index=True,
        doc="Primary key auto increment"
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        doc="Nama pasien"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        doc="Waktu data dibuat (auto-generated)"
    )

    def __repr__(self) -> str:
        return f"<Patient id={self.id} name='{self.name}'>"
