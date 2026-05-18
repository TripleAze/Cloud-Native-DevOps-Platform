# Architecture Documentation

## Overview

This document explains the system architecture of the platform, including runtime components, data flow, and integration with supporting cloud services.

---

## Runtime Architecture

The system follows a microservices-based architecture deployed on Amazon EKS using EKS Auto Mode.

### Architecture Overview

```
Users / Clients
        │
        ▼
Route 53 DNS ──► Application Load Balancer / Ingress (ALB)
                       │
                       ▼
            Kubernetes Cluster (EKS)
              ├── chat-front (Frontend) ───────────────────────┐
              │     (serves Web UI assets over HTTPS)          │
              ├── chat-svc (Backend API & Sockets) ────────────┼──► Database (chat-db Pod)
              │     (runs REST API & Socket.io WebSockets)     │      (natively backed by EBS PVC)
                    │                                               │
                    ▼                                               ▼
              ECR (Container Images)                       ConfigMaps & Secrets
```

---

## Data Flow

- **Frontend Client (chat-front):**
  Static assets are served via HTTPS. The client browser connects to the backend API host resolved through Route 53.
  
- **Backend API & WebSockets (chat-svc):**
  Processes REST queries on `/api`, holds persistent Socket.io WebSockets on `/socket.io`, and connects to the database.

- **Storage Engine (chat-db & EBS SC):**
  Uses EKS Auto Mode's native provisioner (`ebs.csi.eks.amazonaws.com`) to dynamically map GP3 volumes to pods.

- **Secrets and Configuration Management:**
  Docker configurations and credentials are dynamically mapped via namespaced Kubernetes ConfigMaps and Secrets.


---

## Design Considerations

- Scalability via Kubernetes and Karpenter  
- Fault isolation using microservices  
- Observability through integrated monitoring  
- Secure secret management using AWS services  

---

## Delivery Architecture

The platform uses a GitOps-based CI/CD pipeline to automate the build, security scanning, and deployment of containerized services.

### Pipeline Overview

```
Developer / Dev Team
        │
        ▼
Application Repository (GitHub - App Code)
        │
        ▼
CI Pipeline (GitHub Actions)
  ├── Code checkout
  ├── Static Code Scan
  ├── Build Application
  ├── Run Tests
  ├── Build Docker Image
  ├── Image Security Scan
  ├── Tag Image
  ├── Push Image to ECR
  └── Update Manifest Repository
        │
        ├──────────────────────────────┐
        ▼                              ▼
Container Registry             Deployment Repository
  (Amazon ECR)               (GitHub - K8s Manifests)
                                       │
                                       ▼
                               GitOps Tools (ArgoCD)
                                       │
                                       ▼
                            Kubernetes Cluster (EKS)
```

### Components

- **Developer / Dev Team**
  - Pushes application code to the Application Repository

- **Application Repository** *(GitHub - App Code)*
  - Source of truth for application source code; triggers the CI pipeline on push

- **CI Pipeline** *(GitHub Actions)*
  - Automates the full build and publish lifecycle:
    - Checks out source code
    - Runs static code analysis
    - Builds and tests the application
    - Builds and scans the Docker image for security vulnerabilities
    - Tags and pushes the image to Amazon ECR
    - Updates the Kubernetes manifest in the Deployment Repository

- **Container Registry** *(Amazon ECR)*
  - Stores versioned and immutable Docker images consumed by the cluster

- **Deployment Repository** *(GitHub - K8s Manifests)*
  - Source of truth for Kubernetes manifests; updated automatically by the CI pipeline

- **GitOps Tools** *(ArgoCD)*
  - Monitors the Deployment Repository and reconciles the desired state with the live cluster

- **Kubernetes Cluster** *(EKS)*
  - Executes workloads; kept in sync by ArgoCD

### Delivery Flow

1. Developer pushes code → **Application Repository**
2. GitHub Actions CI pipeline triggers automatically
3. Pipeline builds, tests, scans, and pushes the Docker image to **ECR**
4. Pipeline updates the image tag in the **Deployment Repository**
5. **ArgoCD** detects the manifest change and syncs the new version to **EKS**