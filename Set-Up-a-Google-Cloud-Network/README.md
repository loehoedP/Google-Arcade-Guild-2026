# Set Up a Google Cloud Network: Challenge Lab (GSP314)

Solution and automated bash script to complete **Set Up a Google Cloud Network: Challenge Lab (GSP314)** on Google Cloud Skills Boost / Google Cloud Arcade.

## How to Run in Cloud Shell

Resource names and regions are different in every lab instance. Copy the values from your lab instructions and pass them as environment variables:

```bash
curl -LO https://raw.githubusercontent.com/loehoedP/Google-Arcade-Guild-2026/main/Set-Up-a-Google-Cloud-Network/GSP314.sh
chmod +x GSP314.sh

REGION_A=europe-west4 ZONE_A=europe-west4-a \
REGION_B=us-west1     ZONE_B=us-west1-c \
VPC_NAME=vpc-network-xxxx \
SUBNET_A=subnet-a-xxxx SUBNET_B=subnet-b-xxxx \
FW_SSH=xxxx-firewall-ssh FW_RDP=xxxx-firewall-rdp FW_ICMP=xxxx-firewall-icmp \
./GSP314.sh
```

Any variable you leave out uses the default from the script. `VM_A`, `VM_B`, `SUBNET_A_RANGE`, `SUBNET_B_RANGE` and `MACHINE_TYPE` can be overridden the same way.

## Tasks Covered

- **Task 1:** Create networks (custom VPC + 2 subnets)
- **Task 2:** Add firewall rules (SSH, RDP, ICMP)
- **Task 3:** Add VMs to your network and verify connectivity
