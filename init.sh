#!/bin/bash
set -e

# Caminho do bench: /workspace/frappe-bench (sua pasta local mapeada)
BENCH_PATH="/workspace/frappe-bench"

if [ -d "${BENCH_PATH}/apps/frappe" ]; then
    echo "Bench already exists, starting..."
    cd "${BENCH_PATH}"
    bench start
    exit 0
fi

echo "Creating new bench at ${BENCH_PATH}..."

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

# Salva o medacademy customizado se existir
if [ -d "${BENCH_PATH}/apps/medacademy" ]; then
    echo "Preserving existing medacademy app..."
    mv "${BENCH_PATH}/apps/medacademy" /tmp/medacademy-preserved
fi

cd /workspace
bench init --skip-redis-config-generation frappe-bench
cd "${BENCH_PATH}"

# Usa os containers em vez de localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis e watch do Procfile (não precisa em container)
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

# Pega os apps oficiais
bench get-app payments
bench get-app lms

# Restaura o medacademy se foi preservado
if [ -d /tmp/medacademy-preserved ]; then
    echo "Restoring medacademy app..."
    mv /tmp/medacademy-preserved "${BENCH_PATH}/apps/medacademy"
fi

# Cria o site
bench new-site lms.localhost \
  --force \
  --mariadb-root-password 123 \
  --admin-password admin \
  --no-mariadb-socket

# Instala os apps no site
bench --site lms.localhost install-app payments
bench --site lms.localhost install-app lms

# Instala o medacademy se foi restaurado
if [ -d "${BENCH_PATH}/apps/medacademy" ]; then
    echo "Installing medacademy..."
    pip install -e "${BENCH_PATH}/apps/medacademy"
    bench --site lms.localhost install-app medacademy
fi

# Configurações Brasil / pt-BR
bench --site lms.localhost set-config developer_mode 1
bench --site lms.localhost set-config lang pt-BR
bench --site lms.localhost set-config time_zone "America/Sao_Paulo"
bench --site lms.localhost set-config currency BRL
bench --site lms.localhost set-config country Brazil
bench --site lms.localhost set-config date_format "dd/mm/yyyy"
bench --site lms.localhost set-config number_format "#.###,##"

bench --site lms.localhost clear-cache

bench use lms.localhost
bench start
