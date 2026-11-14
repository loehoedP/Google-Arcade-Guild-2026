#!/usr/bin/env bash
# GSP523 - Implement Multimodal Vector Search with BigQuery: Challenge Lab

set -euo pipefail

ask() {
  local _cur="${!1:-}"
  if [[ -n "$_cur" ]]; then echo "$1 = $_cur (from env)"; return; fi
  if [[ -t 0 ]]; then
    local _v
    read -rp "$3 [$2]: " _v
    printf -v "$1" '%s' "${_v:-$2}"
  else
    printf -v "$1" '%s' "$2"
  fi
  echo "$1 = ${!1}"
}

step() { echo; echo "=============================================================="; echo ">> $1"; echo "=============================================================="; }

PROJECT="${DEVSHELL_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
[[ -n "$PROJECT" ]] || { echo "Project not set. Run: gcloud config set project <ID>"; exit 1; }

# ================================================================= Preparation
step "Preparation: Dataset, Region, and Naming"

if [[ -z "${DATASET:-}" ]]; then
  DATASET=$(bq ls --format=json --max_results=1000 2>/dev/null \
    | jq -r '.[].datasetReference.datasetId' | grep -m1 'bqml_dataset' || true)
fi
[[ -n "${DATASET:-}" ]] || { echo "Dataset *_bqml_dataset not found. Set manually: DATASET=<name> bash $0"; exit 1; }
echo "DATASET = $DATASET"

PREFIX="${DATASET%_bqml_dataset}"
echo "PREFIX = $PREFIX"

REGION="${REGION:-$(bq show --format=json "${PROJECT}:${DATASET}" | jq -r '.location' | tr 'A-Z' 'a-z')}"
echo "REGION = $REGION"

CONN="${CONN:-vector_conn}"
OBJECT_TABLE="${OBJECT_TABLE:-${PREFIX}_image_object_table}"
MODEL="${MODEL:-${PREFIX}_embedding}"
EMBED_TABLE="${EMBED_TABLE:-${PREFIX}_retail_store_embeddings}"
SEARCH_TABLE="${SEARCH_TABLE:-${PREFIX}_vector_search_table}"
BUCKET="${BUCKET:-$PROJECT}"
ask SEARCH_PHRASE "Men Sweaters" "Search phrase (Task 4)"
TOP_K="${TOP_K:-2}"

echo "CONN=$CONN OBJECT_TABLE=$OBJECT_TABLE MODEL=$MODEL"
echo "EMBED_TABLE=$EMBED_TABLE SEARCH_TABLE=$SEARCH_TABLE BUCKET=gs://$BUCKET"

run_sql() { bq query --project_id="$PROJECT" --location="$REGION" --use_legacy_sql=false --quiet "$1"; }

# ------------------------------------------------------------------- Task 1
step "Task 1: Connection $CONN + IAM"

if bq show --connection --project_id="$PROJECT" --location="$REGION" "$CONN" >/dev/null 2>&1; then
  echo "--- Connection $CONN already exists"
else
  bq mk --connection --project_id="$PROJECT" --location="$REGION" \
    --connection_type=CLOUD_RESOURCE "$CONN"
fi

SA=$(bq show --connection --format=json --project_id="$PROJECT" --location="$REGION" "$CONN" \
  | jq -r '.cloudResource.serviceAccountId')
[[ -n "$SA" && "$SA" != "null" ]] || { echo "Connection service account not found."; exit 1; }
echo "--- Service account: $SA"

for ROLE in roles/bigquery.dataOwner roles/storage.objectViewer roles/aiplatform.user; do
  echo "--- Binding $ROLE"
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$SA" --role="$ROLE" \
    --condition=None --quiet >/dev/null
done

echo "--- Waiting 60 seconds for IAM propagation before using the connection"
sleep 60

# ------------------------------------------------------------------- Task 2
step "Task 2: Object table $OBJECT_TABLE"

run_sql "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT}.${DATASET}.${OBJECT_TABLE}\`
WITH CONNECTION \`${PROJECT}.${REGION}.${CONN}\`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://${BUCKET}/*']
)"

# ------------------------------------------------------------------- Task 3
step "Task 3: Model $MODEL + Embeddings table $EMBED_TABLE"

run_sql "
CREATE OR REPLACE MODEL \`${PROJECT}.${DATASET}.${MODEL}\`
REMOTE WITH CONNECTION \`${PROJECT}.${REGION}.${CONN}\`
OPTIONS (endpoint = 'multimodalembedding@001')"

echo "--- Generating embeddings (one model call per image, please wait)"
run_sql "
CREATE OR REPLACE TABLE \`${PROJECT}.${DATASET}.${EMBED_TABLE}\` AS
SELECT *, REGEXP_EXTRACT(uri, r'[^/]+$') AS product_name
FROM ML.GENERATE_EMBEDDING(
  MODEL \`${PROJECT}.${DATASET}.${MODEL}\`,
  TABLE \`${PROJECT}.${DATASET}.${OBJECT_TABLE}\`
)"

echo "--- Embedding results summary:"
bq query --project_id="$PROJECT" --location="$REGION" --use_legacy_sql=false \
  "SELECT COUNT(*) AS total_rows,
          COUNTIF(ml_generate_embedding_status != '') AS failed
   FROM \`${PROJECT}.${DATASET}.${EMBED_TABLE}\`"

# ------------------------------------------------------------------- Task 4
step "Task 4: Vector search -> $SEARCH_TABLE"

run_sql "
CREATE OR REPLACE TABLE \`${PROJECT}.${DATASET}.${SEARCH_TABLE}\` AS
SELECT base.uri, base.product_name, base.content_type, distance
FROM VECTOR_SEARCH(
  TABLE \`${PROJECT}.${DATASET}.${EMBED_TABLE}\`, 'ml_generate_embedding_result',
  (
    SELECT ml_generate_embedding_result AS embedding_col
    FROM ML.GENERATE_EMBEDDING(
      MODEL \`${PROJECT}.${DATASET}.${MODEL}\`,
      (SELECT '${SEARCH_PHRASE}' AS content),
      STRUCT(TRUE AS flatten_json_output)
    )
  ),
  top_k => ${TOP_K},
  distance_type => 'COSINE'
)"

echo "--- Contents of $SEARCH_TABLE:"
bq query --project_id="$PROJECT" --location="$REGION" --use_legacy_sql=false \
  "SELECT * FROM \`${PROJECT}.${DATASET}.${SEARCH_TABLE}\` ORDER BY distance"

cat <<EOF

--------------------------------------------------------------
DONE! Go back to the lab page ([Implement Multimodal Vector Search with BigQuery: Challenge Lab](https://www.skills.google/course_templates/1232)) and click 'Check my progress' for:
  Task 1 - Create a source connection and grant IAM permissions
  Task 2 - Create an object table
  Task 3 - Create a new model and generate embeddings
  Task 4 - Run a vector search
--------------------------------------------------------------
EOF