# AWS Core Networking & Compute (Terraform)

Reference Infrastructure-as-Code (IaC) repository demonstrating a multi-VPC AWS network and compute architecture built with modular Terraform and automated CI security/linting pipelines.

## Architecture Overview

```mermaid
flowchart TB
    Internet((Internet))
    Admin([Admin / DevOps Engineer])

    subgraph AccountA["Account A: Shared Services / Network Hub (10.0.0.0/16)"]
        IGW_A[Internet Gateway]
        subgraph PubSubA["Public Subnets (Multi-AZ)"]
            Bastion["Bastion Host<br/>(Elastic IP)"]
            NAT_A[NAT Gateway]
        end
        TGW((AWS Transit Gateway))
    end

    subgraph AccountB["Account B: Production Workload (10.1.0.0/16)"]
        IGW_B[Internet Gateway]
        subgraph PubSubB["Public Subnets (Multi-AZ)"]
            ALB[Application Load Balancer]
            NAT_B[NAT Gateway]
        end
        subgraph PrivSubB["Private Subnets (Multi-AZ)"]
            ASG["EC2 Auto Scaling Group<br/>(Launch Template)"]
            EBS[("Encrypted EBS Volumes<br/>+ DLM Snapshots")]
            ASG --- EBS
        end
        VPCE["Gateway VPC Endpoints<br/>(S3 & DynamoDB)"]
    end

    subgraph AccountC["Account C: Legacy / Analytics (10.2.0.0/16)"]
        subgraph PrivSubC["Private Subnets"]
            LegacyApp[Analytics / Internal Services]
        end
    end

    subgraph AWSManaged["AWS Managed Services (Private Backbone)"]
        S3[(Amazon S3)]
        DDB[(Amazon DynamoDB)]
    end

    %% External Connections
    Internet <--> IGW_B
    IGW_B <--> ALB
    Admin -- "SSH (Restricted IP)" --> Bastion
    Bastion <--> IGW_A <--> Internet

    %% Internal Traffic
    ALB --> ASG
    Bastion -- "Admin Access" --> TGW
    TGW <--> PrivSubB
    ASG -. "Outbound Updates" .-> NAT_B --> IGW_B
    ASG -- "Private Traffic (No NAT Cost)" --> VPCE
    VPCE <--> S3
    VPCE <--> DDB

    %% Cross-Account VPC Peering
    PrivSubB <-- "Cross-Account VPC Peering" --> PrivSubC

    %% Styling
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#232F3E,font-weight:bold;
    classDef net fill:#E3F2FD,stroke:#1565C0,stroke-width:1.5px,color:#0D47A1;
    classDef sec fill:#E8F5E9,stroke:#2E7D32,stroke-width:1.5px,color:#1B5E20;
    
    class TGW,ALB,VPCE aws;
    class IGW_A,IGW_B,NAT_A,NAT_B net;
    class Bastion,ASG,EBS,LegacyApp sec;
```

## Implemented Infrastructure Components

1. **Core VPC Networking:** Multi-AZ VPCs with isolated Public and Private subnets, Internet Gateways (IGW), and NAT Gateways.
2. **Multi-AZ Compute & Load Balancing:** Application Load Balancer (ALB) distributing traffic across an EC2 Auto Scaling Group (ASG) in private subnets.
3. **Secure Bastion Access:** Bastion Host with a dedicated **Elastic IP** and strict Security Group ingress rules.
4. **Persistent Storage & Backups:** Encrypted **EBS volumes** attached to EC2 instances with automated snapshot policies via AWS Data Lifecycle Manager (DLM).
5. **Transit Gateway (Hub-and-Spoke):** Centralized routing between the Shared Services Hub VPC and Production VPC.
6. **Cross-Account VPC Peering:** Direct private peering connection between Production and Legacy/Analytics VPCs using provider aliases.
7. **VPC Endpoints:** Gateway Endpoints for **Amazon S3** and **DynamoDB** to route traffic privately and eliminate NAT Gateway data transfer costs.

## Repository Structure

```text
.
├── .github/workflows/       # GitHub Actions CI (fmt, validate, tflint, trivy)
├── modules/
│   ├── vpc/                 # VPC, Subnets, IGW, NAT, Route Tables, VPC Endpoints
│   ├── transit-gateway/     # Transit Gateway, VPC Attachments & Routing
│   ├── vpc-peering/         # Cross-account VPC Peering & Accepter
│   ├── bastion/             # Bastion EC2, Elastic IP & Security Group
│   └── compute/             # ALB, Launch Template, ASG, EBS Volumes & DLM Snapshots
└── environments/
    └── prod/                # Root configuration assembling all modules
```
