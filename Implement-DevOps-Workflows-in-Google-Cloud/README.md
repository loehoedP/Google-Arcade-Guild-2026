# Implement DevOps Workflows in Google Cloud: Challenge Lab (GSP330)

Solution and automated bash script to complete **Implement DevOps Workflows in Google Cloud: Challenge Lab (GSP330)** on Google Cloud Skills Boost / Google Cloud Arcade.

## How to Run in Cloud Shell

Run the following commands in Google Cloud Shell:

```bash
curl -LO https://raw.githubusercontent.com/loehoedP/Google-Arcade-Guild-2026/main/Implement-DevOps-Workflows-in-Google-Cloud/GSP330.sh
chmod +x GSP330.sh
./GSP330.sh
```

The script prompts for the lab **region**, **zone**, and **Git server IP** (detected automatically from the `git-server` VM). Press Enter to accept the defaults, or set them up front, e.g. `REGION=us-east1 ZONE=us-east1-b ./GSP330.sh`. Creating the GKE cluster takes about 7 minutes.

## Tasks Covered

- **Task 1:** Create the lab resources (APIs, IAM, Artifact Registry, GKE cluster `hello-cluster`, `prod` and `dev` namespaces)
- **Task 2:** Connect to the Git repository on the Git server
- **Task 3:** Create the Cloud Build triggers
- **Task 4:** Deploy the first versions of the application (v1.0)
- **Task 5:** Deploy the second versions of the application (v2.0)
- **Task 6:** Roll back the production deployment to v1.0
