#!/bin/bash
# =============================================================
# Script 03 — Bootstrap MySQL Router
# Milestone 4: Menghubungkan MySQL Router ke InnoDB Cluster
# =============================================================
#
# MySQL Router di-bootstrap secara otomatis via Docker image
# mysql/mysql-router:8.0 menggunakan environment variable.
#
# Script ini untuk BOOTSTRAP MANUAL jika container router
# gagal bootstrap otomatis.
#
# Cara menjalankan:
#   chmod +x scripts/03-bootstrap-router.sh
#   ./scripts/03-bootstrap-router.sh
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

echo "============================================================"
echo " mysql-ha-lab — Bootstrap MySQL Router"
echo "============================================================"
echo " Menjalankan bootstrap di dalam container mysql-router..."
echo "============================================================"
echo ""

# Bootstrap MySQL Router dari dalam container
docker exec mysql-router \
  mysqlrouter \
  --bootstrap "${ADMIN_USER}:${ADMIN_PASS}@mysql1:3306" \
  --conf-use-sockets \
  --user=mysqlrouter \
  --conf-base-port=6446 \
  --force

echo ""
echo ">>> Restart container mysql-router..."
docker compose restart mysql-router
sleep 10

echo ""
echo ">>> Verifikasi Router..."
docker exec mysql-router mysqlrouter --version
echo ""
echo ">>> Port yang aktif:"
echo "  RW (Read/Write) : port 6446"
echo "  RO (Read Only)  : port 6447"

echo ""
echo "============================================================"
echo " ✓ MySQL Router berhasil di-bootstrap!"
echo " Cek koneksi:"
echo "   mysql -u ${ADMIN_USER} -p${ADMIN_PASS} -h 127.0.0.1 -P 6446"
echo "============================================================"
