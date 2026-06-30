# mysql-ha-lab Development Milestones

## Project Information

**Project Name:** mysql-ha-lab

**Objective**

Membangun sebuah lab sederhana untuk mempelajari implementasi **MySQL High Availability** menggunakan **MySQL InnoDB Cluster** dan **MySQL Router** berbasis Docker Compose.

Repository ini berfungsi sebagai media pembelajaran sekaligus Proof of Concept (POC), sehingga seluruh implementasi harus mudah dipahami, terdokumentasi dengan baik, serta dapat direplikasi oleh pengguna lain.

---

# Development Workflow

Project dikembangkan secara bertahap (incremental).

Setiap milestone harus memenuhi syarat berikut:

* Seluruh source code dapat dijalankan.
* Dokumentasi pada milestone tersebut telah selesai.
* Seluruh pengujian berhasil.
* Tidak boleh melanjutkan milestone berikutnya apabila milestone sebelumnya belum berhasil.

---

# Milestone 1 — Project Foundation

## Objective

Menyiapkan struktur repository dan seluruh kebutuhan dasar project.

## Deliverables

* Struktur repository
* README.md
* docker-compose.yml
* .env.example
* Direktori docs
* Direktori scripts
* Direktori api
* Network Docker
* Volume Docker
* Docker healthcheck
* Naming convention

## Validation

* docker compose config berhasil
* docker compose up berhasil
* Semua container berjalan
* Semua volume berhasil dibuat
* Semua network berhasil dibuat

## Documentation

* Project Overview
* Repository Structure
* Prerequisites
* Quick Start

---

# Milestone 2 — Deploy MySQL Cluster Nodes

## Objective

Menjalankan tiga instance MySQL sebagai calon anggota cluster.

## Deliverables

* mysql1
* mysql2
* mysql3

Seluruh node memiliki:

* hostname
* volume persistence
* root password
* user administrator
* konfigurasi dasar MySQL

## Validation

* Ketiga node dapat diakses.
* MySQL berjalan normal.
* Container restart tanpa error.
* Data tetap ada setelah restart container.

## Documentation

* Penjelasan setiap node
* Port mapping
* Volume mapping
* Cara masuk ke container
* Cara login MySQL

---

# Milestone 3 — Configure InnoDB Cluster

## Objective

Membentuk MySQL InnoDB Cluster secara manual menggunakan MySQL Shell.

## Deliverables

* configureInstance()
* createCluster()
* addInstance()
* status()

## Validation

Output cluster harus menunjukkan:

* 1 Primary
* 2 Secondary

Seluruh node dalam status ONLINE.

## Documentation

Menjelaskan:

* Mengapa configureInstance diperlukan
* Group Replication
* Cluster Topology
* Primary Election
* Quorum

---

# Milestone 4 — Configure MySQL Router

## Objective

Menghubungkan aplikasi ke MySQL Router sebagai single endpoint.

## Deliverables

* MySQL Router
* Bootstrap Router
* Read/Write Endpoint
* Read Only Endpoint

## Validation

* Router berhasil bootstrap.
* Router dapat mendeteksi Primary.
* Router dapat meneruskan koneksi ke cluster.

## Documentation

Menjelaskan:

* Fungsi MySQL Router
* Cara kerja routing
* Cara mendeteksi Primary
* Cara kerja failover

---

# Milestone 5 — REST API

## Objective

Membangun REST API sederhana sebagai simulasi aplikasi produksi.

## Technology

* FastAPI
* SQLAlchemy
* MySQL Connector

## Database

Table:

patients

Kolom:

* id
* name
* created_at

## Endpoint

GET /patients

GET /patients/{id}

POST /patients

DELETE /patients/{id}

## Validation

* Swagger dapat diakses.
* CRUD berjalan normal.
* API menggunakan MySQL Router.
* Tidak ada koneksi langsung ke mysql1.

## Documentation

* Struktur API
* Konfigurasi database
* Environment Variable
* Swagger

---

# Milestone 6 — Functional Testing

## Objective

Memastikan seluruh fungsi berjalan normal.

## Test Scenario

* Create Patient
* Read Patient
* Delete Patient
* Restart API
* Restart Router
* Restart Database

## Validation

Semua endpoint tetap berjalan.

---

# Milestone 7 — Failover Testing

## Objective

Membuktikan High Availability berjalan.

## Test Scenario

1. Insert data.
2. Verifikasi data.
3. Matikan Primary.
4. Tunggu proses election.
5. Insert data kembali.
6. Verifikasi data berhasil.
7. Nyalakan kembali Primary.
8. Verifikasi node kembali sebagai Secondary.

## Validation

* API tetap berjalan.
* Tidak ada perubahan konfigurasi aplikasi.
* Primary berpindah otomatis.
* Data tetap konsisten.

---

# Milestone 8 — Recovery Testing

## Objective

Menguji proses recovery setelah node kembali aktif.

## Test Scenario

* Start kembali node.
* Sinkronisasi replication.
* Verifikasi cluster.
* Verifikasi data.

## Validation

Node kembali ONLINE.

Node menjadi SECONDARY.

Data tetap sinkron.

---

# Milestone 9 — Troubleshooting Guide

## Objective

Menyediakan panduan penyelesaian masalah.

## Topics

* Cluster tidak terbentuk
* Router gagal bootstrap
* Node OFFLINE
* Node ERROR
* API gagal koneksi
* Docker Volume Error
* Network Error

Setiap masalah harus memiliki:

* Gejala
* Penyebab
* Langkah penyelesaian
* Cara verifikasi

---

# Milestone 10 — Final Documentation

## Objective

Menyempurnakan dokumentasi project.

## Deliverables

README lengkap.

Diagram Mermaid.

Instruksi instalasi.

Instruksi deployment.

Instruksi pengujian.

Best Practice.

Production Notes.

Repository siap dipublikasikan.

---

# Definition of Done

Project dinyatakan selesai apabila:

* Seluruh container dapat dijalankan menggunakan docker compose.
* InnoDB Cluster berhasil terbentuk.
* MySQL Router berfungsi sebagai endpoint tunggal.
* REST API hanya menggunakan MySQL Router.
* Seluruh endpoint API berjalan normal.
* Skenario failover berhasil tanpa perubahan konfigurasi aplikasi.
* Node yang mati dapat bergabung kembali sebagai Secondary.
* Seluruh langkah memiliki dokumentasi, verifikasi, dan hasil yang diharapkan.
* Repository dapat digunakan sebagai modul praktikum MySQL High Availability dari awal hingga akhir.
