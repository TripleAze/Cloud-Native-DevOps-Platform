# Production-Grade Cloud-Native DevOps Platform

Welcome to the **TripleAze Production-Grade Cloud-Native DevOps Platform**! This repository is a real-world, production-ready blueprint demonstrating how modern engineering teams design, deploy, and operate high-availability microservices-based distributed systems in the cloud.

The platform orchestrates a microservices web chat application on **AWS Elastic Kubernetes Service (EKS)** using **EKS Auto Mode**, leveraging Infrastructure as Code (IaC) with **Terraform**, Continuous Integration (CI) with **GitHub Actions**, Continuous Delivery (CD) via GitOps with **ArgoCD**, and deep observability with **Prometheus, Grafana, and Loki**.

---

## System Overview

The application is a high-performance **Real-Time Web Chat Suite** consisting of:
- **`chat-front`**: A highly interactive, responsive web frontend that leverages WebSockets to send and receive messages in real time.
- **`chat-svc`**: A resilient backend service handling connection pooling, business logic, and database operations.
- **`chat-db`**: A robust transactional MySQL database utilizing persistent K8s volumes for message storage.

---

## Tech Stack & Infrastructure

- **Cloud Platform**: AWS (EKS Auto Mode, ECR, Route 53, ACM, VPC)
- **Container Orchestration**: Kubernetes (EKS Managed gp3 EBS CSI driver)
- **Infrastructure as Code (IaC)**: Terraform
- **GitOps Continuous Delivery**: ArgoCD
- **Continuous Integration (CI)**: GitHub Actions (with manual approval pipelines & SonarCloud SAST analysis)
- **Observability Suite**: Prometheus, Grafana, Loki, and Alertmanager
- **Runtime Tools**: `k9s` (Cluster management TUI), AWS CLI, Helm CLI

---

## Repository Structure

```text
.
├── .github/                 # Automated workflows
│   └── workflows/ci.yml     # Staging & Production deployment pipeline
├── docs/                    # Architecture & Showcase documentation
│   ├── PROJECT_OUTLINE.md   # Core scope & objective outlines
│   └── architecture/
│       ├── README.md        # Detailed runtime & delivery design
│       └── VERIFICATION.md  # 17-screenshot active system verification showcase
├── infra/                   # Infrastructure as Code & Control scripts
│   ├── main.tf              # AWS EKS cluster, network, and security configurations
│   ├── controlled_startup.sh # Dynamic EKS provision, SC, and Route 53 CNAME updates
│   ├── controlled_teardown.sh # Dynamic namespace, Ingress ALB, and infra teardowns
│   ├── cleanup_orphans.sh   # Cleans AWS ELB security groups lockups
│   ├── ebs-sc.yaml          # GP3 dynamic AWS StorageClass definition
│   └── route53_update_all.json # Route 53 record sets batch configurations
├── k8-manifests/            # Version-controlled deployment manifestations (Submodule)
│   ├── base/                # Declarative dry microservices templates
│   ├── overlays/            # Environment-specific overlays
│   │   ├── staging/         # Staging configuration mapping to staging.atiqabubakar.sbs
│   │   └── production/      # High-availability Production mapping to atiqabubakar.sbs
│   ├── argocd/              # ArgoCD declarative app synchronization manifests
│   └── observability/       # Prometheus, Grafana, Loki & Promtail configs & deployers
└── microservices-chat/      # Active application source codes (Frontend, Backend, DB)
```

---

## Environment Delivery Pipeline

I manage isolated environments to guarantee stability and prevent untested code from reaching production:

### Staging Environment (`staging.atiqabubakar.sbs`)
- Automatically deployed when new code is pushed to the staging branch.
- Validates system logic, database migrations, and socket handshakes.

### Production Environment (`atiqabubakar.sbs` & `*.atiqabubakar.sbs`)
- Protected by a **GitHub Actions Manual Approval Gate**.
- Scales microservices automatically under EKS Auto Mode's node group provisions.

---

## Centralized Observability & Incident Alerting

- **Grafana Dashboard (`grafana.atiqabubakar.sbs`)**: Provides real-time metrics visualizers capturing CPU usage, network loads, and connection counts.
- **Loki Log Aggregation**: Streams consolidated log outputs from all Kubernetes pods for quick searchability and forensic debugging.
- **Alertmanager (`http://localhost:9093`)**: Manages incident groups and routing paths for cluster alerts, guaranteeing high system uptime.

---

## Everyday DevOps Operations through my experience of building this Project

I automate cluster lifecycles using targeted automation shell scripts located in `infra/`:

### 1. Cluster Provisioning & Startup
To build the EKS Auto Mode cluster, provision DNS mappings, map EBS storage, and deploy microservices in minutes:
```bash
cd infra/
./controlled_startup.sh
```

### 2. Clean Environment Teardown
To prevent cloud provider costs while keeping the AWS ECR images and AWS ACM SSL Certificates fully intact:
```bash
cd infra/
./controlled_teardown.sh
```

---

## System Verification & Visual Showcase
For full visual proof of my live infrastructure in action (including synchronized ArgoCD pipelines, active container runtimes, and real-time Loki logs), check out these links:
- **[System Verification Portfolio](./docs/architecture/VERIFICATION.md)**
- **[Detailed System Architecture Design](./docs/architecture/README.md)**