# airship / discovery

### Highest-Value Incremental Improvement
The highest-value incremental improvement that can be shipped in under 2 hours is to implement a fix for the HF API rate limit issue. This involves modifying the `train.py` script to download dataset files from the HF CDN instead of using the HF API, which is rate-limited.

### Implementation Plan
1. **Modify `train.py` script**:
	* Add a function to download dataset files from the HF CDN using the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern.
	* Use this function to download the required dataset files instead of using the HF API.
2. **Update `list_repo_tree` API call**:
	* Modify the `list_repo_tree` API call to use the `recursive=False` parameter to avoid paginating through the entire repository.
	* Use the `cdn` parameter to download files from the CDN instead of the API.
3. **Embed file list in training script**:
	* Save the list of file paths to a JSON file after the initial API call.
	* Embed this JSON file in the `train.py` script to avoid making additional API calls during training.

### Code Snippets
```python
import requests

def download_dataset_files(repo, path):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{path}"
    response = requests.get(url)
    with open(path, 'wb') as f:
        f.write(response.content)

# Example usage:
repo = "username/dataset"
path = "data/train.csv"
download_dataset_files(repo, path)
```

```python
import json

def save_file_list(file_list, filename):
    with open(filename, 'w') as f:
        json.dump(file_list, f)

# Example usage:
file_list = ["data/train.csv", "data/test.csv"]
filename = "file_list.json"
save_file_list(file_list, filename)
```

### Benefits
This improvement will allow the training script to download dataset files from the HF CDN, bypassing the rate limit imposed by the HF API. This will enable faster training and reduce the likelihood of rate limit errors. Additionally, embedding the file list in the training script will avoid making additional API calls during training, further improving performance.
