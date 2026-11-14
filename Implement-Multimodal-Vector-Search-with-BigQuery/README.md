# Implement Multimodal Vector Search with BigQuery: Challenge Lab (GSP523)

Solusi dan automated bash script untuk menyelesaikan **Implement Multimodal Vector Search with BigQuery: Challenge Lab (GSP523)** di Google Cloud Skills Boost / Google Cloud Arcade.

## Cara Menjalankan di Cloud Shell

Jalankan perintah berikut di Google Cloud Shell:

```bash
curl -LO https://raw.githubusercontent.com/loehoedP/Google-Arcade-Guild-2026/main/Implement-Multimodal-Vector-Search-with-BigQuery/GSP523.sh
chmod +x GSP523.sh
./GSP523.sh
```

Script akan menanyakan search phrase untuk Task 4 (default: `Men Sweaters`). Nilai lain bisa di-override lewat env var, contoh: `SEARCH_PHRASE="Women Dresses" DATASET=xxx_bqml_dataset ./GSP523.sh`.

## Cakupan Task

- **Task 1:** Create a source connection and grant IAM permissions
- **Task 2:** Create an object table
- **Task 3:** Create a new model and generate embeddings
- **Task 4:** Run a vector search
