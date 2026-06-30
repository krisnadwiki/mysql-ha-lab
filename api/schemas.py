"""
=============================================================
schemas.py — Pydantic Schemas
=============================================================
Mendefinisikan bentuk request dan response untuk API.
Memisahkan layer validasi dari layer database.
=============================================================
"""

from datetime import datetime
from pydantic import BaseModel, Field


# ── Request Schema ───────────────────────────────────────────

class PatientCreate(BaseModel):
    """Schema untuk membuat pasien baru (POST /patients)."""

    name: str = Field(
        ...,
        min_length=1,
        max_length=255,
        description="Nama pasien",
        examples=["Budi Santoso"]
    )

    model_config = {
        "json_schema_extra": {
            "examples": [
                {"name": "Budi Santoso"}
            ]
        }
    }


# ── Response Schema ──────────────────────────────────────────

class PatientResponse(BaseModel):
    """Schema untuk response data pasien."""

    id: int = Field(description="ID unik pasien")
    name: str = Field(description="Nama pasien")
    created_at: datetime = Field(description="Waktu data dibuat")

    model_config = {
        "from_attributes": True,   # Untuk konversi dari SQLAlchemy model
        "json_schema_extra": {
            "examples": [
                {
                    "id": 1,
                    "name": "Budi Santoso",
                    "created_at": "2025-01-01T10:00:00"
                }
            ]
        }
    }
