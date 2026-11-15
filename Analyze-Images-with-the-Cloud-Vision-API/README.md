# Analyze Images with the Cloud Vision API: Challenge Lab (ARC122)

Solution and automated bash script to complete **Analyze Images with the Cloud Vision API: Challenge Lab (ARC122)** on Google Cloud Skills Boost / Google Cloud Arcade.

## How to Run in Cloud Shell

Run the following commands in Google Cloud Shell:

```bash
curl -LO https://raw.githubusercontent.com/loehoedP/Google-Arcade-Guild-2026/main/Analyze-Images-with-the-Cloud-Vision-API/ARC122.sh
chmod +x ARC122.sh
./ARC122.sh
```

The script uses the bucket `<PROJECT_ID>-bucket` and picks the first `.jpg`/`.jpeg`/`.png` image in it automatically.

## Tasks Covered

- **Task 1:** Create an API key
- **Task 2:** Upload an image to a Cloud Storage bucket (made publicly readable)
- **Task 3:** Analyze the image with `TEXT_DETECTION` and `LANDMARK_DETECTION`, and upload `text-response.json` / `landmark-response.json` to the bucket
