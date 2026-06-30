"""
=============================================================
routers/patients.py — Patients Router
=============================================================
Endpoint CRUD untuk resource patients:

  GET    /patients        — Ambil semua pasien
  GET    /patients/{id}   — Ambil pasien berdasarkan ID
  POST   /patients        — Buat pasien baru
  DELETE /patients/{id}   — Hapus pasien berdasarkan ID
=============================================================
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from models import Patient
from schemas import PatientCreate, PatientResponse

router = APIRouter(
    prefix="/patients",
    tags=["patients"],
)


# ── GET /patients ────────────────────────────────────────────
@router.get(
    "/",
    response_model=List[PatientResponse],
    summary="Ambil semua pasien",
    description="Mengembalikan daftar seluruh pasien yang terdaftar.",
)
def get_patients(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    """
    Ambil semua pasien dengan pagination opsional.

    - **skip**: Jumlah data yang dilewati (default: 0)
    - **limit**: Jumlah maksimal data (default: 100)
    """
    patients = db.query(Patient).offset(skip).limit(limit).all()
    return patients


# ── GET /patients/{id} ───────────────────────────────────────
@router.get(
    "/{patient_id}",
    response_model=PatientResponse,
    summary="Ambil pasien berdasarkan ID",
    description="Mengembalikan data satu pasien berdasarkan ID.",
)
def get_patient(patient_id: int, db: Session = Depends(get_db)):
    """
    Ambil pasien berdasarkan ID.

    - **patient_id**: ID unik pasien
    """
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Pasien dengan ID {patient_id} tidak ditemukan.",
        )
    return patient


# ── POST /patients ───────────────────────────────────────────
@router.post(
    "/",
    response_model=PatientResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Buat pasien baru",
    description="Membuat data pasien baru dan menyimpannya ke database.",
)
def create_patient(patient: PatientCreate, db: Session = Depends(get_db)):
    """
    Buat pasien baru.

    - **name**: Nama pasien (wajib diisi)
    """
    db_patient = Patient(name=patient.name)
    db.add(db_patient)
    db.commit()
    db.refresh(db_patient)
    return db_patient


# ── DELETE /patients/{id} ────────────────────────────────────
@router.delete(
    "/{patient_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Hapus pasien",
    description="Menghapus data pasien berdasarkan ID.",
)
def delete_patient(patient_id: int, db: Session = Depends(get_db)):
    """
    Hapus pasien berdasarkan ID.

    - **patient_id**: ID unik pasien yang akan dihapus
    """
    patient = db.query(Patient).filter(Patient.id == patient_id).first()
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Pasien dengan ID {patient_id} tidak ditemukan.",
        )
    db.delete(patient)
    db.commit()
    return None
