#!/bin/bash
# =============================================================
# Script 01 — Configure MySQL Instances
# Milestone 3: Menyiapkan setiap node agar bisa bergabung
#              ke InnoDB Cluster menggunakan dba.configureInstance()
# =============================================================
#
# Prasyarat:
#   - Semua container mysql1, mysql2, mysql3 sudah running
#   - MySQL Shell (mysqlsh) terinstall di host
#
# Cara menjalankan:
#   chmod +x scripts/01-configure-instances.sh
#   ./scripts/01-configure-instances.sh
# =============================================================

set -e

# ── Load environment variables ──────────────────────────────
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "ERROR: File .env tidak ditemukan!"
  echo "Salin .env.example menjadi .env terlebih dahulu:"
  echo "  cp .env.example .env"
  exit 1
fi

ROOT_PASS="${MYSQL_ROOT_PASSWORD}"
ADMIN_USER="${MYSQL_ADMIN_USER}"
ADMIN_PASS="${MYSQL_ADMIN_PASSWORD}"

NODES=("mysql1:3306" "mysql2:3307" "mysql3:3308")

echo "============================================================"
echo " mysql-ha-lab — Configure Instances"
echo "============================================================"
echo ""

# ── Fungsi: configureInstance untuk satu node ────────────────
configure_node() {
  local HOST=$1
  local PORT=$2

  echo ">>> Configuring ${HOST}:${PORT} ..."

  mysqlsh --no-wizard \
    --uri "root:${ROOT_PASS}@${HOST}:${PORT}" \
    --py \
    --execute "
import time

print('  → Menjalankan dba.configureInstance() pada ${HOST}...')

dba.configure_instance('root:${ROOT_PASS}@${HOST}:${PORT}', {
    'clusterAdmin': '${ADMIN_USER}',
    'clusterAdminPassword': '${ADMIN_PASS}',
    'restart': True,
    'interactive': False
})

print('  ✓ ${HOST} berhasil dikonfigurasi.')
"

  echo ""
  echo "  Menunggu ${HOST} restart..."
  sleep 15
  echo "  ✓ ${HOST} siap."
  echo ""
}

# ── Konfigurasi semua node ───────────────────────────────────
configure_node "127.0.0.1" "3306"   # mysql1
configure_node "127.0.0.1" "3307"   # mysql2
configure_node "127.0.0.1" "3308"   # mysql3

echo "============================================================"
echo " ✓ Semua instance berhasil dikonfigurasi!"
echo " Langkah berikutnya: jalankan 02-create-cluster.sh"
echo "============================================================"
