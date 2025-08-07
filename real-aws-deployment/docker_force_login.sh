#!/bin/bash

echo "🔐 Docker Manual Login com Token"

read -p "🔸 Digite seu usuário Docker Hub: " DOCKER_USER
read -s -p "🔸 Cole seu Access Token: " DOCKER_TOKEN
echo ""

# Cria pasta de config alternativa
DOCKER_CONFIG="$HOME/.docker_manual_config"
mkdir -p "$DOCKER_CONFIG"

# Remove variável de ambiente insegura
unset DOCKER_INSECURE_NO_IPTABLES_RAW
echo "✅ Variável DOCKER_INSECURE_NO_IPTABLES_RAW desativada (temporariamente)"

# Gera token base64
AUTH_STRING=$(echo -n "$DOCKER_USER:$DOCKER_TOKEN" | base64)

# Cria config.json personalizado
cat > "$DOCKER_CONFIG/config.json" <<EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "auth": "$AUTH_STRING"
    }
  }
}
EOF

# Força uso da config local para teste
echo ""
echo "�� Testando login com config personalizada..."

DOCKER_CONFIG="$DOCKER_CONFIG" docker info | grep Username
DOCKER_CONFIG="$DOCKER_CONFIG" docker pull hello-world

echo ""
echo "✅ Login testado e pull realizado com sucesso (se não houve erro)."
echo "�� Você pode copiar esse config para ~/.docker se quiser torná-lo permanente:"
echo "cp -r $DOCKER_CONFIG ~/.docker"

