# AWS Core Networking & Compute (Terraform)

Reference Infrastructure-as-Code (IaC) project demonstrating core AWS networking, compute, storage, and security concepts using modular Terraform and automated CI checks.

## Architecture Overview

```mermaid
flowchart TB
    Internet((Internet))
    Admin([Admin / Developer])

    subgraph MainVPC["Main Production VPC (10.0.0.0/16)"]
        IGW[Internet Gateway]
        
        subgraph PubSub["Public Subnets (Multi-AZ)"]
            ALB[Application Load Balancer]
            NAT[NAT Gateway]
            Bastion["Bastion Host<br/>(Elastic IP)"]
        end
        
        subgraph PrivSub["Private Subnets (Multi-AZ)"]
            ASG["EC2 Auto Scaling Group<br/>(Web Servers)"]
            EBS[("Encrypted EBS Volumes<br/>+ Automated Snapshots")]
            ASG --- EBS
        end
        
        VPCE["Gateway VPC Endpoints<br/>(S3 & DynamoDB)"]
    end

    subgraph SecondaryVPC["Internal / Analytics VPC (10.1.0.0/16)"]
        subgraph PrivSub2["Private Subnets"]
            InternalApp[Internal Service / DB]
        end
    end

    subgraph AWSServices["AWS Managed Services"]
        S3[(Amazon S3)]
        DDB[(Amazon DynamoDB)]
    end

    %% External Traffic
    Internet <--> IGW
    IGW <--> ALB
    Admin -- "SSH (My IP only)" --> Bastion
    Bastion <--> IGW

    %% Internal Routing
    ALB --> ASG
    Bastion -- "SSH via Private IP" --> ASG
    ASG -. "OS Updates / Packages" .-> NAT --> IGW
    ASG -- "Private Traffic (Free)" --> VPCE
    VPCE <--> S3
    VPCE <--> DDB

    %% VPC Peering
    PrivSub <-- "VPC Peering Connection" --> PrivSub2

    %% Styling
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#232F3E,font-weight:bold;
    classDef net fill:#E3F2FD,stroke:#1565C0,stroke-width:1.5px,color:#0D47A1;
    classDef sec fill:#E8F5E9,stroke:#2E7D32,stroke-width:1.5px,color:#1B5E20;

    class ALB,VPCE aws;
    class IGW,NAT net;
    class Bastion,ASG,EBS,InternalApp sec;
```

## Implemented Infrastructure Components

* **Core VPC Networking:** Custom VPC segmented into Public and Private subnets across two Availability Zones (Multi-AZ) for high availability, complete with an Internet Gateway (IGW) and NAT Gateway.
* **High Availability Compute:** An Application Load Balancer (ALB) in public subnets distributing traffic to an Auto Scaling Group (ASG) of EC2 instances isolated in private subnets.
* **Secure Administration (Bastion Host):** A hardened Bastion Host with a static **Elastic IP** in the public subnet, allowing SSH access to private instances strictly from an authorized IP address.
* **Persistent Storage & Backups:** Encrypted **EBS volumes** attached to EC2 instances with automated backup policies (Snapshots) managed via AWS Data Lifecycle Manager (DLM).
* **Private AWS Service Access:** **Gateway VPC Endpoints** for S3 and DynamoDB so private EC2 instances can access storage over the internal AWS network without paying for NAT Gateway traffic.
* **VPC Peering:** Direct private network connection between the Main Production VPC (`10.0.0.0/16`) and a secondary Internal VPC (`10.1.0.0/16`) with updated route tables.

## Repository Structure

```text
.
├── .github/workflows/   # CI pipeline (terraform fmt, validate, tflint, trivy)
├── modules/
│   ├── vpc/             # VPC, Subnets, IGW, NAT, Route Tables, VPC Endpoints
│   ├── compute/         # ALB, Security Groups, Launch Template, ASG, EBS + Snapshots
│   ├── bastion/         # Bastion EC2, Elastic IP & Security Group
│   └── peering/         # VPC Peering connection & cross-VPC routes
└── environments/
    └── dev/             # Root configuration assembling all modules
```
