# vanguard / discovery

### 1. **Diagnosis**
* The Vanguard project lacks a comprehensive solution to handle HF API rate limits, which can block dataset training and hinder the project's progress.
* The current implementation does not utilize the HF CDN bypass strategy, which can download public dataset files without being subject to the HF API rate limits.
* The project's training pipeline is not optimized for performance, leading to potential bottlenecks and inefficiencies.
* The project's codebase lacks a unified approach to handling errors and exceptions, making it difficult to debug and maintain.
* The project's documentation is incomplete, making it challenging for new contributors to understand the project's architecture and implementation details.

### 2. **Proposed change**
The proposed change is to implement the HF CDN bypass strategy in the training pipeline to download public dataset files without being subject to the HF API rate limits. This change will be implemented in the `train.py` file, specifically in the `load_dataset` function.

### 3. **Implementation**
To implement the HF CDN bypass strategy, we will modify the `load_dataset` function to download public dataset files from the HF CDN instead of using the HF API. We will use the `requests` library to download the files and the `pyarrow` library to parse the files.

```python
import requests
import pyarrow.parquet as pq

def load_dataset(repo_id, dataset_name):
    # Get the list of files in the dataset
    files = requests.get(f"https://huggingface.co/datasets/{repo_id}/resolve/main/{dataset_name}").json()

    # Download each file from the HF CDN
    for file in files:
        file_url = f"https://huggingface.co/datasets/{repo_id}/resolve/main/{dataset_name}/{file}"
        response = requests.get(file_url)
        with open(file, "wb") as f:
            f.write(response.content)

    # Parse the downloaded files using pyarrow
    tables = []
    for file in files:
        table = pq.read_table(file)
        tables.append(table)

    # Return the parsed tables
    return tables
```

### 4. **Verification**
To verify that the HF CDN bypass strategy is working correctly, we can check the following:

* The `load_dataset` function is able to download the public dataset files from the HF CDN without being subject to the HF API rate limits.
* The downloaded files are parsed correctly using pyarrow.
* The training pipeline is able to use the parsed tables without any errors.

We can verify these points by running the training pipeline with the modified `load_dataset` function and checking the output for any errors or issues. Additionally, we can use tools like `curl` or `wget` to verify that the files are being downloaded correctly from the HF CDN.
