# surrogate-1 / discovery

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits on the discovery side, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources and increased costs.
* The project does not have a mechanism to bypass the Hugging Face API rate limit for dataset training, which can be achieved by using the HF CDN.

### Proposed change
The proposed change is to implement a mechanism to bypass the Hugging Face API rate limit for dataset training by using the HF CDN. This can be achieved by modifying the `train.py` script to download dataset files from the HF CDN instead of using the Hugging Face API.

### Implementation
To implement this change, we need to modify the `train.py` script as follows:
```python
import json
import os

# Download dataset files from HF CDN
def download_dataset_files(repo, path):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{path}"
    # Download files from HF CDN
    os.system(f"wget {url}")

# Load dataset files
def load_dataset(repo, path):
    # Download dataset files from HF CDN
    download_dataset_files(repo, path)
    # Load dataset files
    dataset = []
    for file in os.listdir(path):
        if file.endswith(".parquet"):
            dataset.append(pd.read_parquet(os.path.join(path, file)))
    return pd.concat(dataset, ignore_index=True)

# Train model
def train_model(dataset):
    # Train model using dataset
    model = ...
    model.fit(dataset)
    return model

# Main function
def main():
    repo = "axentx/surrogate-1"
    path = "data/train"
    dataset = load_dataset(repo, path)
    model = train_model(dataset)
    # Save model
    model.save("model.pth")

if __name__ == "__main__":
    main()
```
We also need to modify the `list_repo_tree` function to download the list of files from the HF CDN instead of using the Hugging Face API:
```python
def list_repo_tree(repo, path):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{path}"
    # Download list of files from HF CDN
    response = requests.get(url)
    files = response.json()
    return files
```
### Verification
To verify that the change works, we can run the `train.py` script and check that the dataset files are downloaded from the HF CDN and used for training. We can also check the Hugging Face API logs to ensure that the rate limit is not exceeded. Additionally, we can monitor the Lightning Studio instances to ensure that they are reused efficiently and not recreated unnecessarily.
