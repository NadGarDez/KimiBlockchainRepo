#!/bin/bash

# --- Colores para una mejor salida en la terminal ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}--- Intentando desplegar el contrato Ticket en la red 'local' ---${NC}"
echo -e "${YELLOW}Asegúrate de que tu nodo Hardhat (o Anvil/Ganache) ya esté corriendo en http://192.168.1.102:8545 ${NC}"

# Ejecuta el comando de despliegue
# Captura el código de salida del comando de despliegue
npx hardhat ignition deploy ./ignition/modules/Ticket.ts --network local
DEPLOY_STATUS=$?

# Verifica el resultado del despliegue
if [ $DEPLOY_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Contrato desplegado exitosamente.${NC}"
else
    echo -e "${RED}❌ Error al desplegar el contrato. Por favor, verifica que tu nodo esté corriendo y la configuración de red en hardhat.config.ts.${NC}"
    echo -e "${RED}Código de salida: ${DEPLOY_STATUS}${NC}"
fi

echo -e "${GREEN}Proceso de despliegue finalizado.${NC}"
