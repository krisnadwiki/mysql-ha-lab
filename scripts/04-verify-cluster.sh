#!/bin/bash
# =============================================================
# Script 04 — Verify Cluster Status
# Milestone 3 & 7: Verifikasi status InnoDB Cluster
# =============================================================
#
# Cara menjalankan:
#   chmod +x scripts/04-verify-cluster.sh
#   ./scripts/04-verify-cluster.sh
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
echo " mysql-ha-lab — Cluster Status"
echo "============================================================"
echo ""

mysqlsh --no-wizard \
  --uri "${ADMIN_USER}:${ADMIN_PASS}@127.0.0.1:3306" \
  --py \
  --execute "
import json

print('>>> Mendapatkan referensi cluster...')
cluster = dba.get_cluster()

print('')
print('>>> Status Cluster:')
status = cluster.status()
print(json.dumps(status, indent=2, default=str))

print('')
print('>>> Topology:')
topology = status.get('defaultReplicaSet', {}).get('topology', {})
for member, info in topology.items():
    role = info.get('memberRole', 'UNKNOWN')
    state = info.get('status', 'UNKNOWN')
    print(f'  {member:30s} | {role:10s} | {state}')
"

echo ""
echo "============================================================"
echo " ✓ Verifikasi selesai"
echo "============================================================"
