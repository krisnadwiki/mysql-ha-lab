#!/bin/bash
# =============================================================
# Script 02 — Create InnoDB Cluster
# Milestone 3: Membentuk cluster dari mysql1 sebagai Primary,
#              lalu menambahkan mysql2 dan mysql3 sebagai Secondary
# =============================================================
#
# Prasyarat:
#   - Script 01-configure-instances.sh sudah berhasil dijalankan
#   - MySQL Shell (mysqlsh) terinstall di host
#
# Cara menjalankan:
#   chmod +x scripts/02-create-cluster.sh
#   ./scripts/02-create-cluster.sh
# =============================================================

set -e

# ── Load environment variables ──────────────────────────────
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "ERROR: File .env tidak ditemukan!"
  exit 1
fi

ADMIN_USER="${MYSQL_ADMIN_USER}"
ADMIN_PASS="${MYSQL_ADMIN_PASSWORD}"
CLUSTER="${CLUSTER_NAME:-myCluster}"

echo "============================================================"
echo " mysql-ha-lab — Create InnoDB Cluster"
echo "============================================================"
echo " Cluster Name : ${CLUSTER}"
echo " Primary      : mysql1 (127.0.0.1:3306)"
echo " Secondary    : mysql2 (127.0.0.1:3307)"
echo " Secondary    : mysql3 (127.0.0.1:3308)"
echo "============================================================"
echo ""

mysqlsh --no-wizard \
  --uri "${ADMIN_USER}:${ADMIN_PASS}@127.0.0.1:3306" \
  --py \
  --execute "
import time

# ── Step 1: Buat cluster dari mysql1 ────────────────────────
print('>>> Step 1: Membuat cluster dari mysql1...')
cluster = dba.create_cluster('${CLUSTER}', {
    'multiPrimary': False,
    'force': False,
    'interactive': False
})
print('  ✓ Cluster berhasil dibuat dengan mysql1 sebagai Primary.')
print('')

# ── Step 2: Tambahkan mysql2 ────────────────────────────────
print('>>> Step 2: Menambahkan mysql2 sebagai Secondary...')
cluster.add_instance('${ADMIN_USER}:${ADMIN_PASS}@mysql2:3306', {
    'recoveryMethod': 'clone',
    'interactive': False,
    'waitRecovery': 3
})
print('  ✓ mysql2 berhasil bergabung sebagai Secondary.')
print('')

# ── Step 3: Tambahkan mysql3 ────────────────────────────────
print('>>> Step 3: Menambahkan mysql3 sebagai Secondary...')
cluster.add_instance('${ADMIN_USER}:${ADMIN_PASS}@mysql3:3306', {
    'recoveryMethod': 'clone',
    'interactive': False,
    'waitRecovery': 3
})
print('  ✓ mysql3 berhasil bergabung sebagai Secondary.')
print('')

# ── Step 4: Tampilkan status cluster ────────────────────────
print('>>> Step 4: Status Cluster:')
import json
status = cluster.status()
print(json.dumps(status, indent=2, default=str))
"

echo ""
echo "============================================================"
echo " ✓ InnoDB Cluster berhasil dibentuk!"
echo " Langkah berikutnya: jalankan 03-bootstrap-router.sh"
echo "============================================================"
