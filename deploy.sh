#!/bin/bash
set -e

echo "================================================"
echo " DEPLOYMENT AUTOMATION SCRIPT"
echo "================================================"

# Verificar que JWT_SECRET esté definido
if [ -z "$JWT_SECRET" ]; then
  echo " Error: JWT_SECRET no está definido"
  exit 1
fi

# Exportar como variable de Terraform
export TF_VAR_jwt_secret="$JWT_SECRET"

echo ""
echo "=== FASE 1: Configurando Zipkin ==="
echo " Esperando 90 segundos para que los servicios se desplieguen..."
sleep 90

echo "🔍 Obteniendo información de Zipkin..."

# Obtener ARN del task de Zipkin
ZIPKIN_TASK_ARN=$(aws ecs list-tasks \
  --cluster todos-cluster \
  --service-name zipkin \
  --region us-west-2 \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$ZIPKIN_TASK_ARN" ] || [ "$ZIPKIN_TASK_ARN" == "None" ]; then
  echo " Error: No se pudo obtener el Task ARN de Zipkin"
  exit 1
fi

echo " Task ARN de Zipkin: $ZIPKIN_TASK_ARN"

# Esperar a que el task esté corriendo
echo " Esperando a que Zipkin esté RUNNING..."
aws ecs wait tasks-running \
  --cluster todos-cluster \
  --tasks "$ZIPKIN_TASK_ARN" \
  --region us-west-2

# Obtener ENI
ZIPKIN_ENI=$(aws ecs describe-tasks \
  --cluster todos-cluster \
  --tasks "$ZIPKIN_TASK_ARN" \
  --region us-west-2 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

echo " ENI de Zipkin: $ZIPKIN_ENI"

# Obtener IP pública
ZIPKIN_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ZIPKIN_ENI" \
  --region us-west-2 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo " IP pública de Zipkin: $ZIPKIN_IP"

# Construir nueva URL
NEW_ZIPKIN_URL="http://${ZIPKIN_IP}:9411/api/v2/spans"
OLD_ZIPKIN_URL="http://34.222.102.63:9411/api/v2/spans"

echo " Nueva URL de Zipkin: $NEW_ZIPKIN_URL"

# Actualizar main.tf
echo " Actualizando main.tf con la nueva IP de Zipkin..."
sed -i "s|${OLD_ZIPKIN_URL}|${NEW_ZIPKIN_URL}|g" main.tf

echo " main.tf actualizado"
echo ""
echo " Ejecutando segundo Terraform Apply..."
terraform apply -auto-approve

echo ""
echo "=== FASE 2: Configurando TODOs API ==="
echo " Esperando 90 segundos para que TODOs API se actualice..."
sleep 90

echo " Obteniendo información de TODOs API..."

# Obtener ARN del task de TODOs API
TODOS_TASK_ARN=$(aws ecs list-tasks \
  --cluster todos-cluster \
  --service-name todos-api \
  --region us-west-2 \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$TODOS_TASK_ARN" ] || [ "$TODOS_TASK_ARN" == "None" ]; then
  echo " Error: No se pudo obtener el Task ARN de TODOs API"
  exit 1
fi

echo " Task ARN de TODOs API: $TODOS_TASK_ARN"

# Esperar a que el task esté corriendo
echo " Esperando a que TODOs API esté RUNNING..."
aws ecs wait tasks-running \
  --cluster todos-cluster \
  --tasks "$TODOS_TASK_ARN" \
  --region us-west-2

# Obtener ENI
TODOS_ENI=$(aws ecs describe-tasks \
  --cluster todos-cluster \
  --tasks "$TODOS_TASK_ARN" \
  --region us-west-2 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

echo " ENI de TODOs API: $TODOS_ENI"

# Obtener IP pública
TODOS_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$TODOS_ENI" \
  --region us-west-2 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)

echo " IP pública de TODOs API: $TODOS_IP"

# Obtener hostname DNS
echo " Resolviendo hostname DNS..."
TODOS_HOSTNAME=$(nslookup $TODOS_IP | grep 'name =' | awk '{print $4}' | sed 's/\.$//')

if [ -z "$TODOS_HOSTNAME" ]; then
  echo " Error: No se pudo resolver el hostname"
  exit 1
fi

echo " Hostname de TODOs API: $TODOS_HOSTNAME"

# Actualizar CloudFront domain_name
OLD_DOMAIN="ec2-52-12-100-10.us-west-2.compute.amazonaws.com"

echo " Actualizando domain_name en CloudFront..."
sed -i "s|domain_name = \"${OLD_DOMAIN}\"|domain_name = \"${TODOS_HOSTNAME}\"|g" main.tf

echo " main.tf actualizado"
echo ""
echo " Ejecutando tercer Terraform Apply..."
terraform apply -auto-approve

echo ""
echo "================================================"
echo " DEPLOYMENT COMPLETADO EXITOSAMENTE"
echo "================================================"
echo ""
echo " Resumen:"
echo "  🔹 Zipkin URL: $NEW_ZIPKIN_URL"
echo "  🔹 TODOs API Hostname: $TODOS_HOSTNAME"
echo ""
echo " ¡Todo listo!"