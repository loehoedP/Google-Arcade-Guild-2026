#!/bin/bash

# ==============================================================================
# Lab: Analyze Images with the Cloud Vision API: Challenge Lab (ARC122)
# Description: Automates API key creation, bucket permissions, and image 
#              analysis (TEXT_DETECTION & LANDMARK_DETECTION) using Cloud Vision API.
# ==============================================================================

set -e

echo "Starting Cloud Vision API Challenge Lab automation..."

# 1. Set environment variables dynamically
export PROJECT_ID=$(gcloud config get-value project)
export BUCKET_NAME="${PROJECT_ID}-bucket"

# Automatically fetch the image filename inside the bucket
export IMAGE_NAME=$(gcloud storage ls "gs://${BUCKET_NAME}" | grep -E '\.(jpg|jpeg|png)$' | head -n 1 | xargs basename)

if [ -z "$IMAGE_NAME" ]; then
  echo "Error: No image file found in gs://${BUCKET_NAME}"
  exit 1
fi

echo "Project ID : $PROJECT_ID"
echo "Bucket     : $BUCKET_NAME"
echo "Image File : $IMAGE_NAME"

# 2. Enable required Google Cloud APIs
echo "Enabling Cloud Vision and API Keys services..."
gcloud services enable vision.googleapis.com apikeys.googleapis.com --quiet

# 3. Create an API Key and retrieve the key string
echo "Creating API Key..."
KEY_NAME=$(gcloud services api-keys create --display-name="vision-api-key" --format="value(name)")
export API_KEY=$(gcloud services api-keys get-key-string "$KEY_NAME" --format="value(keyString)")

if [ -z "$API_KEY" ]; then
  echo "Error: Failed to retrieve API_KEY."
  exit 1
fi
echo "API Key successfully generated."

# 4. Make the Cloud Storage bucket publicly readable
echo "Setting public read access on gs://${BUCKET_NAME}..."
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member=allUsers \
  --role=roles/storage.objectViewer \
  --quiet

# 5. Task 2 & 3 (Part 1): Perform TEXT_DETECTION
echo "Creating request.json for TEXT_DETECTION..."
cat << EOF > request.json
{
  "requests": [
    {
      "image": {
        "source": {
          "gcsImageUri": "gs://${BUCKET_NAME}/${IMAGE_NAME}"
        }
      },
      "features": [
        {
          "type": "TEXT_DETECTION"
        }
      ]
    }
  ]
}
EOF

echo "Calling Cloud Vision API for TEXT_DETECTION..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  --data-binary @request.json \
  "https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" \
  -o text-response.json

echo "Uploading text-response.json to Cloud Storage..."
gcloud storage cp text-response.json "gs://${BUCKET_NAME}/text-response.json"

# 6. Task 3 (Part 2): Perform LANDMARK_DETECTION
echo "Updating request.json for LANDMARK_DETECTION..."
cat << EOF > request.json
{
  "requests": [
    {
      "image": {
        "source": {
          "gcsImageUri": "gs://${BUCKET_NAME}/${IMAGE_NAME}"
        }
      },
      "features": [
        {
          "type": "LANDMARK_DETECTION"
        }
      ]
    }
  ]
}
EOF

echo "Calling Cloud Vision API for LANDMARK_DETECTION..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  --data-binary @request.json \
  "https://vision.googleapis.com/v1/images:annotate?key=${API_KEY}" \
  -o landmark-response.json

echo "Uploading landmark-response.json to Cloud Storage..."
gcloud storage cp landmark-response.json "gs://${BUCKET_NAME}/landmark-response.json"

echo "All tasks completed successfully!"