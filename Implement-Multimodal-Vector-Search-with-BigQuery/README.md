# Implement Multimodal Vector Search with BigQuery: Challenge Lab (GSP523)

Solution and automated bash script to complete **Implement Multimodal Vector Search with BigQuery: Challenge Lab (GSP523)** on Google Cloud Skills Boost / Google Cloud Arcade.

## How to Run in Cloud Shell

Run the following commands in Google Cloud Shell:

```bash
curl -LO https://raw.githubusercontent.com/loehoedP/Google-Arcade-Guild-2026/main/Implement-Multimodal-Vector-Search-with-BigQuery/GSP523.sh
chmod +x GSP523.sh
./GSP523.sh
```

The script prompts for the Task 4 search phrase (default: `Men Sweaters`). Other values can be overridden with environment variables, e.g. `SEARCH_PHRASE="Women Dresses" DATASET=xxx_bqml_dataset ./GSP523.sh`.

## Tasks Covered

- **Task 1:** Create a source connection and grant IAM permissions
- **Task 2:** Create an object table
- **Task 3:** Create a new model and generate embeddings
- **Task 4:** Run a vector search
