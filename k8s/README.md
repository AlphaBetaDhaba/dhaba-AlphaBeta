# Dhaba Orders — Kubernetes Manifests

Kustomize-based manifests for the Dhaba Orders microservices platform (ShipIt Sprint 3, C8).

---

## 1. Directory Structure

```text
k8s/
├── base/
│   ├── kustomization.yaml             # Root base kustomization
│   ├── namespace.yaml                 # Namespace documentation and reference
│   ├── configmap.yaml                 # Common non-sensitive environment configuration
│   ├── ingress.yaml                   # Ingress resources (dhaba-ingress-api & dhaba-ingress-web)
│   ├── menu-api/                      # Deployment, ClusterIP Service, PDB
│   ├── orders-api/                    # Deployment, ClusterIP Service, PDB
│   ├── kitchen-worker/                # Deployment, PDB (no Service — queue worker)
│   ├── stats-api/                     # Deployment, ClusterIP Service, PDB
│   ├── web/                           # Deployment, ClusterIP Service, PDB
│   ├── postgres/                      # StatefulSet with PVC template, ClusterIP Service
│   └── redis/                         # StatefulSet with PVC template, ClusterIP Service
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml         # Staging overlay (dhaba-staging namespace)
    │   └── patches/
    │       ├── ingress-host.yaml      # Sets host to staging.TEAM.test
    │       ├── configmap.yaml         # Sets APP_ENV=staging, APP_DEBUG=true
    │       ├── resources-*.yaml       # Lighter resource requests/limits (5 files)
    │       └── pdb-*.yaml             # Staging PDBs with minAvailable: 1 (5 files)
    └── production/
        ├── kustomization.yaml         # Production overlay (dhaba-production namespace)
        └── patches/
            ├── ingress-host.yaml      # Sets host to TEAM.test
            ├── replicas-*.yaml        # Scales stateless services to 2 replicas (5 files)
            ├── resources-*.yaml       # Production resource requests/limits (5 files)
            ├── topology-*.yaml        # Topology spread across kubernetes.io/hostname (5 files)
            └── pdb-*.yaml             # Production PDBs with minAvailable: 1 (5 files)
```

### Purpose of Base and Overlays
- **`base/`**: Holds declarations common to all environments. StatefulSets (`postgres`, `redis`) run single replicas with persistent storage. Deployments default to 1 replica with standard probes, secrets references, and baseline resource requests.
- **`overlays/staging/`**: Targets the `dhaba-staging` namespace. Patches the ConfigMap for staging (`APP_ENV=staging`, `APP_DEBUG=true`), provides staging ingress hostname (`staging.TEAM.test`), allocates lighter resource requests/limits, and applies `minAvailable: 1` PDBs.
- **`overlays/production/`**: Targets the `dhaba-production` namespace. Scales all stateless services to at least 2 replicas, applies production ingress hostname (`TEAM.test`), sets production resource limits, enforces strict node topology spread constraints (`DoNotSchedule` across `kubernetes.io/hostname`), and maintains `minAvailable: 1` PDBs.

---

## 2. Namespace Creation

Namespaces are separated per environment. Create them prior to deployment:

```bash
kubectl create namespace dhaba-staging
kubectl create namespace dhaba-production
```

---

## 3. Creating Application Secrets (`dhaba-secret`)

> **Security Rule:** Secret manifests containing real or default credentials must **never** be committed to source control. They must be created imperatively or injected through a secure secrets store.

All workloads requiring credentials read from a Kubernetes Secret named `dhaba-secret` in their respective namespace.

### Keys Required in `dhaba-secret`

| Secret Key | Required By Services | Purpose / Notes |
|---|---|---|
| `DB_PASSWORD` | `menu-api`, `orders-api`, `kitchen-worker`, `stats-api`, `postgres` | Password for PostgreSQL user `dhaba`. The `postgres` StatefulSet maps this to `POSTGRES_PASSWORD` so credentials remain consistent. |
| `APP_KEY` | `stats-api` | Laravel 32-character application encryption key (e.g. `base64:...`). Generate using `php artisan key:generate --show`. |

### Commands to Create `dhaba-secret`

Replace placeholders with your actual values:

```bash
# Staging namespace
kubectl create secret generic dhaba-secret \
  --namespace dhaba-staging \
  --from-literal=DB_PASSWORD='<SECURE_DATABASE_PASSWORD>' \
  --from-literal=APP_KEY='<SECURE_LARAVEL_APP_KEY>'

# Production namespace
kubectl create secret generic dhaba-secret \
  --namespace dhaba-production \
  --from-literal=DB_PASSWORD='<SECURE_DATABASE_PASSWORD>' \
  --from-literal=APP_KEY='<SECURE_LARAVEL_APP_KEY>'
```

---

## 4. ECR Image Pull Secret (`ecr-registry`)

All stateless application Deployments specify:
```yaml
imagePullSecrets:
  - name: ecr-registry
```

Because Kubernetes Secrets are namespaced, `ecr-registry` must exist in **both** `dhaba-staging` and `dhaba-production`.

### Commands to Create `ecr-registry`

```bash
# 1. Fetch auth token from AWS ECR
ECR_TOKEN=$(aws ecr get-login-password --region us-east-1)

# 2. Create in staging
kubectl create secret docker-registry ecr-registry \
  --namespace dhaba-staging \
  --docker-server=267278679790.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}"

# 3. Create in production
kubectl create secret docker-registry ecr-registry \
  --namespace dhaba-production \
  --docker-server=267278679790.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}"
```

> **Note on Token Expiry:** AWS ECR authorization tokens expire after 12 hours. Refresh them periodically using a scheduled cron job or automated secret refresher.

---

## 5. Ingress Configuration and API Route Rewrites

### Ingress Architecture
To prevent a global `nginx.ingress.kubernetes.io/rewrite-target` annotation from corrupting requests to the web service (such as static JavaScript, CSS, or React HTML fallback routes), two distinct Ingress resources are configured:

1. **`dhaba-ingress-api`**:
   - Annotations:
     ```yaml
     nginx.ingress.kubernetes.io/use-regex: "true"
     nginx.ingress.kubernetes.io/rewrite-target: /$1
     ```
   - Routes:
     - `/api/(menu.*)` → rewrites to `/menu` → routes to `menu-api:8001`
     - `/api/(orders.*)` → rewrites to `/orders` → routes to `orders-api:8002`
     - `/api/(stats.*)` → rewrites to `/stats` → routes to `stats-api:80`
     - Direct fallback routes `/(menu.*)`, `/(orders.*)`, and `/(stats.*)` are also mapped to preserve direct backend compatibility.

2. **`dhaba-ingress-web`**:
   - Contains **no** rewrite annotations.
   - Maps `/` with `pathType: Prefix` directly to the `web:80` Service.
   - Preserves exact URIs for frontend assets (`/assets/*`, `/index.html`).

### Hostnames
- **Staging:** `staging.TEAM.test`
- **Production:** `TEAM.test`

*(Replace `TEAM` with your designated team identifier prior to cluster deployment).*

---

## 6. Staging vs Production Differences

| Feature | Staging (`dhaba-staging`) | Production (`dhaba-production`) |
|---|---|---|
| **Namespace** | `dhaba-staging` | `dhaba-production` |
| **Ingress Host** | `staging.TEAM.test` | `TEAM.test` |
| **ConfigMap `APP_ENV`** | `staging` | `production` |
| **ConfigMap `APP_DEBUG`** | `true` | `false` |
| **Stateless Service Replicas** | 1 replica per service | 2 replicas per service (including `kitchen-worker`) |
| **Stateless Resource Sizing** | Lighter requests/limits | Sized for production workloads |
| **Topology Spread Constraints** | None (single-node compatible) | Enforced: `kubernetes.io/hostname`, `maxSkew: 1`, `DoNotSchedule` |
| **PodDisruptionBudgets (PDB)** | `minAvailable: 1` | `minAvailable: 1` |
| **StatefulSets (`postgres`, `redis`)** | 1 replica with PVC | 1 replica with PVC |

---

## 7. PodDisruptionBudgets (PDB) & Voluntary Disruptions

All 5 stateless services have an associated PDB configured with `minAvailable: 1` in both staging and production.

### Effect on Single-Replica Workloads (Staging)
- When a workload runs with `replicas: 1` and has a PDB with `minAvailable: 1`, at least 1 pod must remain healthy during voluntary disruptions (e.g. `kubectl drain <node>`).
- If an operator attempts to drain the node hosting that single replica, the Kubernetes Eviction API will **block** eviction with a `Cannot evict pod as it would violate the pod's disruption budget` message.
- To safely drain a node hosting single-replica staging workloads, operators must temporarily scale the deployment to 2 replicas or delete the PDB prior to draining.

### Production Behavior
With `replicas: 2` in production and `minAvailable: 1`, rolling node upgrades or drains can safely evict one pod at a time while the remaining replica continues serving traffic uninterrupted.

---

## 8. Kitchen Worker Concurrency and Health Probes

### Concurrency and Duplicate Processing
- **Queue Mechanism:** The worker consumes orders from Redis list `orders:pending` using `redisTemplate.opsForList().leftPop("orders:pending", Duration.ofSeconds(1))`, which issues an atomic Redis `BLPOP`.
- **Concurrency Safety:** Because Redis single-threads command executions, `BLPOP` atomically pops each item to exactly one caller. Two concurrent worker replicas will never pop or process the same order item.
- **Idempotency:** When an order is processed, the worker updates the order status:
  ```sql
  UPDATE orders SET status='cooking', updated_at=NOW() WHERE id=?
  UPDATE orders SET status='ready', updated_at=NOW() WHERE id=?
  ```
  Setting `status='ready'` is idempotent in terms of terminal state. If an order ID were ever re-submitted, the terminal status remains `ready`.

### Health Probes & Minimum Code Change
- **Why `/proc/1/status` is Inadequate:** Checking `/proc/1/status` only confirms that the Linux kernel process exists. It gives zero visibility into whether the JVM is deadlocked, the Spring ApplicationContext has initialized, or the scheduled worker loops are firing.
- **Why `redis-cli` Cannot Be Used:** The runtime image `eclipse-temurin:21-jre-jammy` contains only a minimal JRE. It does not package `redis-cli`, `curl`, or `wget`. Furthermore, querying a global Redis key (`kitchen:heartbeat`) across multiple replicas cannot isolate which specific worker instance is unhealthy.
- **Minimum Code Change:** In `HeartbeatService.java`, the scheduled heartbeat loop (running every 10 seconds) writes a local timestamp file to `/tmp/heartbeat` upon each successful run.
- **Kubernetes Probe Configuration:**
  - **Readiness Probe:**
    ```yaml
    readinessProbe:
      exec:
        command: ["sh", "-c", "test -f /tmp/heartbeat"]
      initialDelaySeconds: 15
      periodSeconds: 10
      failureThreshold: 3
    ```
    Confirms Spring Boot has completed its startup and written the initial heartbeat.
  - **Liveness Probe:**
    ```yaml
    livenessProbe:
      exec:
        command: ["sh", "-c", "[ $(($(date +%s) - $(date -r /tmp/heartbeat +%s))) -lt 30 ]"]
      initialDelaySeconds: 30
      periodSeconds: 15
      failureThreshold: 3
    ```
    Confirms that the worker's scheduled heartbeat thread has executed within the last 30 seconds. If the worker hangs or crashes, the heartbeat file becomes stale, the probe fails, and Kubernetes restarts the container.

---

## 9. Production Topology Spreading (Multi-Node Requirement)

Production Deployments include:
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
```

- `whenUnsatisfiable: DoNotSchedule` instructs the scheduler not to place a pod if doing so causes node skew to exceed 1.
- In a single-node cluster (e.g. default Minikube), the first replica schedules on node 1. The second replica will remain **`Pending`** because placing both on node 1 would violate `maxSkew: 1`.
- **Production scheduling must be tested on a multi-node cluster** (e.g. `minikube start --nodes 3` or Amazon EKS).

---

## 10. Validation and Inspection Commands

### Validate Kustomize Builds (Dry-Run)

Validate using `minikube kubectl`:
```bash
minikube kubectl -- kustomize k8s/overlays/staging
minikube kubectl -- kustomize k8s/overlays/production
```

Or using standalone `kustomize`:
```bash
kustomize build k8s/overlays/staging
kustomize build k8s/overlays/production
```

### Apply Overlays (Do Not Run Until Cluster Prerequisites Are Set)

```bash
# Staging
kubectl apply -k k8s/overlays/staging

# Production
kubectl apply -k k8s/overlays/production
```

### Enable Minikube Ingress Addon

```bash
minikube addons enable ingress
```

### Configure Local Hostnames

Retrieve the Minikube IP:
```bash
minikube ip
```

Add to `/etc/hosts`:
```text
<MINIKUBE_IP>   TEAM.test
<MINIKUBE_IP>   staging.TEAM.test
```

### Inspect Deployed Resources

```bash
TARGET_NS=dhaba-staging  # or dhaba-production

kubectl get deployments -n $TARGET_NS
kubectl get pods -n $TARGET_NS -o wide
kubectl get services -n $TARGET_NS
kubectl get statefulsets -n $TARGET_NS
kubectl get pvc -n $TARGET_NS
kubectl get pdb -n $TARGET_NS
kubectl get ingress -n $TARGET_NS
```
