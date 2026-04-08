## Deploying a Production-Ready 3-Tier Architecture on Azure using Terraform

**1. Introduction to the Architecture** [0:00](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=0)

![generated-image-at-00:00:00](https://loom.com/i/c8a6618b328c4379abe78bb6becb6941?workflows_screenshot=true)

- Presenter: Srojan
- Overview of a production-ready 3-tier architecture deployed on Azure using Terraform.
- Key design aspects: scalability, security, and high availability.

**2. Overview of the 3 Tiers** [0:12](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=12)

![generated-image-at-00:00:12](https://loom.com/i/4cd9a23eaab34edea1bf0f9511a67fc5?workflows_screenshot=true)

- **Web Tier (Front-End)**: Accessible via an application gateway.
- **App Tier (Back-End)**: Internal services hosted in a private subnet.
- **DB Tier**: Database services, specifically Azure Postgres SQL Flexible Server.

**3. Traffic Routing and Security** [0:30](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=30)

![generated-image-at-00:00:30](https://loom.com/i/f096b4832fc04a61a4e3ee9182415bc0?workflows_screenshot=true)

- Application Gateway applies a web application firewall to securely route traffic.
- Virtual Machine Scale Set (VMSS) runs Docker containers across multiple availability zones.
- Internal load balancer distributes traffic to backend services.

**4. Database Configuration** [1:13](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=73)

![generated-image-at-00:01:13](https://loom.com/i/82a18a40e58a423aaa589e7e77775408?workflows_screenshot=true)

- Utilizes Azure Postgres SQL Flexible Server with: 
  - Primary instance
  - Read replica for high availability and read scalability.
- Accessible only via private endpoints.

**5. Security Measures** [1:35](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=95)

![generated-image-at-00:01:35](https://loom.com/i/270b8904027c4a3bad830eda2cd0c941?workflows_screenshot=true)

- Deployment of Bastion servers for SSH access to VMs.
- NAT Gateway for controlled outbound internet access to pull Docker images.
- Key Vault for secret management (e.g., database credentials, Docker Hub credentials).

**6. Resource Group Structure** [2:31](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=151)

![generated-image-at-00:02:31](https://loom.com/i/ca57ab7b58fd46438bc71365bfae9ad3?workflows_screenshot=true)

- All components are organized within a single resource group named 'prod-rg'.

**7. SIM Lite Application Overview** [3:02](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=182)

![generated-image-at-00:03:02](https://loom.com/i/54681fcab1da482890e8555bd04ae275?workflows_screenshot=true)

- Architecture includes three components: Vegent, Backend, and Dashboard.
- Collects and segregates logs into categories (e.g., authentication logs, error logs).

**8. Terraform Code Structure** [3:32](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=212)

![generated-image-at-00:03:32](https://loom.com/i/1a35476d04004dc19dbeaf2715995722?workflows_screenshot=true)

- Main files: `main.tf`, `output.tf`, `provider.tf`.
- Use of modules for reusable code (e.g., database, DNS, key vault).
- Network security groups defined in `local.tf`.

**9. Network Configuration** [4:30](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=270)

![generated-image-at-00:04:30](https://loom.com/i/98ea781d78c54180adb6ab2b5ae226ca?workflows_screenshot=true)

- Definition of public and private subnets for frontend, backend, and database tiers.
- Dynamic loops used to create necessary network security groups.

**10. Key Vault and Secrets Management** [6:30](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=390)

![generated-image-at-00:06:30](https://loom.com/i/5b01147da7ba4d3fa3226df20d6bebcb?workflows_screenshot=true)

- Key Vault stores secrets like database hostname, username, and Docker Hub credentials.

**11. Deployment Process** [9:30](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=570)

![generated-image-at-00:09:30](https://loom.com/i/74e033b39d41415a8648d4a238bd4d18?workflows_screenshot=true)

- Terraform commands: `init`, `plan`, and `apply` to deploy resources.
- Monitoring deployment progress and handling errors.

**12. Application Testing** [19:38](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=1178)

![generated-image-at-00:19:38](https://loom.com/i/25ee3ffb66f646418ff0d3e8d9388f9e?workflows_screenshot=true)

- Accessing the application via public IP and port.
- Demonstration of the SIM dashboard functionality.

**13. Recap of the Architecture** [22:07](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=1327)

![generated-image-at-00:22:07](https://loom.com/i/7caad141fc4a48d2a67718e73efbbf8d?workflows_screenshot=true)

- Summary of the architecture and its components: 
  - User access through application gateway.
  - Web application firewall and network security groups.
  - Three-tier structure with distinct subnets.

**14. Conclusion** [24:02](https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e?t=1442)

![generated-image-at-00:24:02](https://loom.com/i/414f8a3402fc4505b028807de1a92d65?workflows_screenshot=true)

- Final thoughts on the deployment process and architecture overview.

### Link to Loom

<https://loom.com/share/ef86869a3e354a979b9c3b269c372f8e>
