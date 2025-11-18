# Kubernetes Network Policies - Seguridad por Capas

Este proyecto implementa un modelo de seguridad multinivel en Kubernetes mediante Network Policies. La arquitectura sigue el principio de menor privilegio, donde cada capa de la aplicacion solo puede comunicarse con la capa inmediatamente siguiente.

## Arquitectura

El proyecto define tres capas:

- **Presentation**: Capa de presentacion con servidor UI (Nginx)
- **Business**: Capa de logica de negocio con servidor API
- **Persistence**: Capa de persistencia con base de datos PostgreSQL

El flujo de comunicacion permitido es: `presentation -> business -> persistence`

Cualquier otro flujo de comunicacion esta explicitamente bloqueado por las politicas de red.

## Estructura del Proyecto

```
.
├── manifests/
│   ├── namespaces/
│   │   └── namespaces.yaml
│   ├── deployments/
│   │   ├── presentation-layer.yaml
│   │   ├── business-layer.yaml
│   │   └── persistence-layer.yaml
│   └── policies/
│       ├── default-deny.yaml
│       ├── presentation-policies.yaml
│       ├── business-policies.yaml
│       └── persistence-policies.yaml
├── scripts/
│   └── validate-policies.sh
└── README.md
```

## Requisitos Previos

- Docker instalado
- kubectl instalado
- kind (Kubernetes in Docker) instalado

### Instalacion de Herramientas

#### Instalar kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

#### Instalar kind

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version
```

## Despliegue

### 1. Crear el Cluster de Kubernetes

```bash
kind create cluster --name network-policies-lab
```

### 2. Aplicar los Manifiestos

Aplicar en el siguiente orden:

```bash
kubectl apply -f manifests/namespaces/namespaces.yaml
kubectl apply -f manifests/deployments/
kubectl apply -f manifests/policies/default-deny.yaml
kubectl apply -f manifests/policies/
```

### 3. Verificar los Recursos

```bash
kubectl get namespaces
kubectl get pods -A
kubectl get svc -A
kubectl get networkpolicies -A
```

## Validacion de Politicas

### Ejecucion del Script de Validacion

```bash
chmod +x scripts/validate-policies.sh
./scripts/validate-policies.sh
```

El script realiza las siguientes pruebas:

#### Trafico Permitido (debe exitoso)
- Presentation -> Business: Conexion de UI a API en puerto 8080
- Business -> Persistence: Conexion de API a base de datos en puerto 5432

#### Trafico Bloqueado (debe fallar)
- Persistence -> Business: Intento de conexion inversa desde base de datos
- Presentation -> Persistence: Intento de salto de capa desde UI a base de datos
- Business -> Presentation: Intento de conexion inversa desde API

### Pruebas Manuales

#### Verificar conectividad permitida

```bash
# UI -> API
kubectl exec -n presentation deploy/ui-server -- nc -z -w 3 api-service.business 8080

# API -> Database
kubectl exec -n business deploy/api-server -- nc -z -w 3 database-service.persistence 5432
```

#### Verificar bloqueos de seguridad

```bash
# Database -> API (debe fallar)
kubectl exec -n persistence deploy/database-server -- nc -z -w 3 api-service.business 8080

# UI -> Database (debe fallar)
kubectl exec -n presentation deploy/ui-server -- nc -z -w 3 database-service.persistence 5432

# API -> UI (debe fallar)
kubectl exec -n business deploy/api-server -- nc -z -w 3 ui-service.presentation 80
```

## Politicas de Red Implementadas

### Default Deny

Se aplica una politica de negacion por defecto en cada namespace que bloquea todo el trafico entrante y saliente.

### Politicas Especificas

#### Presentation Layer
- **Ingress**: Permite trafico externo en puerto 80
- **Egress**: Permite conexiones hacia Business layer (puerto 8080) y DNS

#### Business Layer
- **Ingress**: Solo acepta trafico desde Presentation layer en puerto 8080
- **Egress**: Solo permite conexiones hacia Persistence layer (puerto 5432) y DNS

#### Persistence Layer
- **Ingress**: Solo acepta trafico desde Business layer en puerto 5432
- **Egress**: Completamente bloqueado (sin conexiones salientes)

## Limpieza

Para eliminar todos los recursos:

```bash
kind delete cluster --name network-policies-lab
```

## Notas Importantes

- Las politicas de red requieren un plugin CNI que las soporte (kind usa kindnetd por defecto)
- DNS debe estar explicitamente permitido en las reglas de egress para la resolucion de nombres
- El principio de menor privilegio se aplica: solo se permite el trafico estrictamente necesario
- Las politicas son aditivas: multiple politicas aplicadas al mismo pod se combinan