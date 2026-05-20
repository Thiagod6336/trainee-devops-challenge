#!/bin/sh
# healthcheck.sh — Verifica se a API está respondendo
# Uso: ./healthcheck.sh [host] [port]
# Exemplo: ./healthcheck.sh localhost 5000

HOST=${1:-localhost}
PORT=${2:-5000}
URL="http://${HOST}:${PORT}/health"
MAX_RETRIES=5
RETRY_INTERVAL=3

echo "Verificando health da API em: $URL"
echo ""

for i in $(seq 1 $MAX_RETRIES); do
    echo "Tentativa $i/$MAX_RETRIES..."

    HTTP_STATUS=$(wget --server-response --spider --quiet "$URL" 2>&1 \
        | grep "HTTP/" | tail -1 | awk '{print $2}')

    if [ "$HTTP_STATUS" = "200" ]; then
        echo ""
        echo "✅ API saudável! (HTTP $HTTP_STATUS)"
        exit 0
    else
        echo "   Status: ${HTTP_STATUS:-sem resposta}"
        [ "$i" -lt "$MAX_RETRIES" ] && sleep $RETRY_INTERVAL
    fi
done

echo ""
echo "❌ API não responde após $MAX_RETRIES tentativas."
echo "   Verifique: docker ps | docker logs trainee-devops-api"
exit 1
