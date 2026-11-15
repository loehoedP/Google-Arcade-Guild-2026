#!/usr/bin/env bash
# GSP330 - Implement DevOps Workflows in Google Cloud: Challenge Lab (Full Auto + Interactive)
# Usage: ./GSP330.sh

set -euo pipefail

PROJECT_ID="${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
[[ -n "$PROJECT_ID" ]] || { echo "Project belum di-set. Jalankan: gcloud config set project <ID>"; exit 1; }

ask() {
  local _cur="${!1:-}"
  if [[ -n "$_cur" ]]; then echo "$1 = $_cur (dari env)"; return; fi
  if [[ -t 0 ]]; then
    local _v
    read -rp "$3 [$2]: " _v
    printf -v "$1" '%s' "${_v:-$2}"
  else
    printf -v "$1" '%s' "$2"
  fi
  echo "$1 = ${!1}"
}

echo "=== Konfigurasi Variabel Lab (Tekan Enter untuk pakai nilai default) ==="
ask REGION "us-west1"   "Region lab"
ask ZONE   "us-west1-b" "Zone lab"

AUTO_GIT_IP="$(gcloud compute instances describe git-server --zone="$ZONE" --project="$PROJECT_ID" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "34.82.154.77")"
ask GIT_SERVER_IP "$AUTO_GIT_IP" "Git Server IP"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
CLUSTER="hello-cluster"
REPO_DIR="$HOME/sample-app"
AR="my-repository"

IMG_PROD="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR}/hello-cloudbuild"
IMG_DEV="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR}/hello-cloudbuild-dev"
GIT_REMOTE_URL="http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git"

step() {
  echo
  echo "=============================================================="
  echo ">> $1"
  echo "=============================================================="
}

expose_svc() {
  local ns="$1" deploy="$2" svc="$3"
  kubectl -n "$ns" rollout status "deployment/$deploy" --timeout=180s
  kubectl -n "$ns" get service "$svc" >/dev/null 2>&1 || \
    kubectl -n "$ns" expose deployment "$deploy" --name="$svc" \
      --type=LoadBalancer --port=8080 --target-port=8080
}

patch_main_go() {
  grep -q 'redHandler' main.go && { echo "main.go sudah memiliki redHandler."; return; }
  sed -i 's|\thttp.ListenAndServe(":8080", nil)|\thttp.HandleFunc("/red", redHandler)\n\thttp.ListenAndServe(":8080", nil)|' main.go
  cat >> main.go << 'EOF_GO'

func redHandler(w http.ResponseWriter, r *http.Request) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{255, 0, 0, 255}}, image.ZP, draw.Src)
	w.Header().Set("Content-Type", "image/png")
	png.Encode(w, img)
}
EOF_GO
}

# =====================================================================
# TASK 1: Create the lab resources
# =====================================================================
step "Task 1: Set region/zone & enable API"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"
gcloud services enable container.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com --project="$PROJECT_ID"

step "Task 1: Tambah IAM role untuk Cloud Build SA"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/container.developer" --condition=None >/dev/null || true

step "Task 1: Konfigurasi Git global"
git config --global user.name "Student"
git config --global user.email "student@qwiklabs.net"

step "Task 1: Artifact Registry $AR"
gcloud artifacts repositories describe "$AR" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "$AR" \
    --repository-format=docker --location="$REGION" \
    --description="Docker repository" --project="$PROJECT_ID"

step "Task 1: Cluster GKE $CLUSTER (butuh ~7 menit)"
if ! gcloud container clusters describe "$CLUSTER" --zone="$ZONE" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud container clusters create "$CLUSTER" \
    --zone="$ZONE" \
    --release-channel=regular \
    --num-nodes=3 \
    --enable-autoscaling --min-nodes=2 --max-nodes=6 \
    --project="$PROJECT_ID"
else
  echo "Cluster $CLUSTER sudah ada."
fi

gcloud container clusters get-credentials "$CLUSTER" --zone="$ZONE" --project="$PROJECT_ID"

step "Task 1: Namespace prod dan dev"
kubectl get namespace prod >/dev/null 2>&1 || kubectl create namespace prod
kubectl get namespace dev  >/dev/null 2>&1 || kubectl create namespace dev
kubectl get namespace

# =====================================================================
# TASK 2: Connect to the Git repository on the Git server
# =====================================================================
step "Task 2: Salin kode sample-app & ganti placeholder"
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
gcloud storage cp -r gs://spls/gsp330/sample-app/* "$REPO_DIR/"

for f in "$REPO_DIR/cloudbuild-dev.yaml" "$REPO_DIR/cloudbuild.yaml"; do
  sed -i "s/<your-region>/${REGION}/g" "$f"
  sed -i "s/<your-zone>/${ZONE}/g" "$f"
  sed -i "s/<version>/v1.0/g" "$f"
done

step "Task 2: Init Git & push ke Gitea (branch master & dev)"
cd "$REPO_DIR"
git init
git remote add origin "http://${GIT_SERVER_IP}:3000/giteaadmin/sample-app.git"
git branch -m master
git add .
git commit -m "initial commit"
git push -f -u "$GIT_REMOTE_URL" master

git checkout -b dev
git push -f -u "$GIT_REMOTE_URL" dev

# =====================================================================
# TASK 3: Create the Cloud Build Triggers
# =====================================================================
step "Task 3: Buat Cloud Build Triggers (prod & dev)"
gcloud builds triggers describe sample-app-prod-deploy --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1 || \
  gcloud builds triggers create manual \
    --name="sample-app-prod-deploy" \
    --inline-config="cloudbuild.yaml" \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --region="$REGION" \
    --project="$PROJECT_ID"

gcloud builds triggers describe sample-app-dev-deploy --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1 || \
  gcloud builds triggers create manual \
    --name="sample-app-dev-deploy" \
    --inline-config="cloudbuild-dev.yaml" \
    --service-account="projects/${PROJECT_ID}/serviceAccounts/${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --region="$REGION" \
    --project="$PROJECT_ID"

# =====================================================================
# TASK 4: Deploy the first versions of the application (v1.0)
# =====================================================================
step "Task 4 (Dev): Update dev/deployment.yaml v1.0, build & expose"
cd "$REPO_DIR"
git checkout dev
sed -i "s|<todo>|${IMG_DEV}:v1.0|g" dev/deployment.yaml
sed -i "s|PROJECT_ID|${PROJECT_ID}|g" dev/deployment.yaml
git add .
git commit -m "Deploy v1.0 on dev" || true
git push "$GIT_REMOTE_URL" dev
gcloud builds submit --config=cloudbuild-dev.yaml . --project="$PROJECT_ID"
expose_svc dev development-deployment dev-deployment-service

step "Task 4 (Prod): Update prod/deployment.yaml v1.0, build & expose"
git checkout master
sed -i "s|<todo>|${IMG_PROD}:v1.0|g" prod/deployment.yaml
sed -i "s|PROJECT_ID|${PROJECT_ID}|g" prod/deployment.yaml
git add .
git commit -m "Deploy v1.0 on master" || true
git push "$GIT_REMOTE_URL" master
gcloud builds submit --config=cloudbuild.yaml . --project="$PROJECT_ID"
expose_svc prod production-deployment prod-deployment-service

# =====================================================================
# TASK 5: Deploy the second versions of the application (v2.0)
# =====================================================================
step "Task 5 (Dev): Tambah /red & build versi v2.0"
cd "$REPO_DIR"
git checkout dev
patch_main_go
sed -i "s/:v1.0/:v2.0/g" cloudbuild-dev.yaml dev/deployment.yaml
git add .
git commit -m "Deploy v2.0 on dev"
git push "$GIT_REMOTE_URL" dev
gcloud builds submit --config=cloudbuild-dev.yaml . --project="$PROJECT_ID"
kubectl -n dev rollout status deployment/development-deployment --timeout=180s

step "Task 5 (Prod): Tambah /red & build versi v2.0"
git checkout master
patch_main_go
sed -i "s/:v1.0/:v2.0/g" cloudbuild.yaml prod/deployment.yaml
git add .
git commit -m "Deploy v2.0 on master"
git push "$GIT_REMOTE_URL" master
gcloud builds submit --config=cloudbuild.yaml . --project="$PROJECT_ID"
kubectl -n prod rollout status deployment/production-deployment --timeout=180s

# =====================================================================
# TASK 6: Roll back the production deployment to v1.0
# =====================================================================
step "Task 6: Rollback production-deployment ke v1.0"
kubectl -n prod set image deployment/production-deployment \
  "production-container=${IMG_PROD}:v1.0"
kubectl -n prod rollout status deployment/production-deployment --timeout=180s

PROD_LB_IP="$(kubectl -n prod get svc prod-deployment-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo
echo "=============================================================="
echo "SEMUA TASK (1 - 6) SELESAI!"
echo "Prod LoadBalancer IP : ${PROD_LB_IP}"
echo "Verifikasi /red (404): curl -I http://${PROD_LB_IP}:8080/red"
echo "Silakan klik 'Check my progress' pada semua task di halaman lab."
echo "=============================================================="
