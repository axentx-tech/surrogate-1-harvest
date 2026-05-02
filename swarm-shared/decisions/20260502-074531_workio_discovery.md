# workio / discovery

### High-Value Incremental Improvement for Workio Discovery
#### Task: Optimize Dataset Ingestion using HF CDN Bypass
#### Time Estimate: < 2 hours

### Implementation Plan
#### Step 1: Update `ingest.py` to Use HF CDN Bypass for Dataset Download
Modify the `ingest.py` script to download dataset files from the HF CDN instead of using the HF API. This will bypass the rate limit and allow for faster ingestion.

```python
import requests

# Define the dataset repository and file path
repo = "dataset/repo"
file_path = "path/to/file.parquet"

# Download the file from the HF CDN
url = f"https://huggingface.co/datasets/{repo}/resolve/main/{file_path}"
response = requests.get(url)

# Save the file to the local disk
with open(file_path, "wb") as f:
    f.write(response.content)
```

#### Step 2: Implement Paginated Download for Large Datasets
For large datasets, implement a paginated download approach to avoid downloading the entire dataset at once. This will reduce the memory usage and allow for more efficient ingestion.

```python
import requests

# Define the dataset repository and file path
repo = "dataset/repo"
file_path = "path/to/file.parquet"

# Define the page size for paginated download
page_size = 100

# Download the file in pages
for i in range(0, 1000, page_size):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{file_path}?page={i}&page_size={page_size}"
    response = requests.get(url)
    with open(f"{file_path}_{i}.parquet", "wb") as f:
        f.write(response.content)
```

#### Step 3: Update `train.py` to Use the Ingested Dataset
Modify the `train.py` script to use the ingested dataset for training. This will ensure that the training process uses the latest dataset.

```python
import pandas as pd

# Load the ingested dataset
df = pd.read_parquet(file_path)

# Train the model using the ingested dataset
model = train(df)
```

By implementing these steps, we can optimize the dataset ingestion process using the HF CDN bypass and improve the overall efficiency of the Workio discovery pipeline.
