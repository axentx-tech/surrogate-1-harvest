# airship / frontend

### Highest-Value Incremental Improvement
The highest-value incremental improvement that can ship in <2h is to optimize the frontend of the airship project by implementing a CDN bypass for dataset training. This involves pre-listing file paths once, embedding them in the training script, and using the CDN to download dataset files without hitting the HF API rate limit.

### Implementation Plan
1. **Identify Dataset Repositories**: Identify the dataset repositories used in the airship project.
2. **Pre-list File Paths**: Use the HF API to pre-list file paths for each dataset repository. This can be done using the `list_repo_tree` method with `recursive=False`.
3. **Embed File Paths in Training Script**: Embed the pre-listed file paths in the training script. This can be done by saving the file paths to a JSON file and loading them in the training script.
4. **Use CDN for Dataset Downloads**: Modify the training script to use the CDN to download dataset files. This can be done by constructing the CDN URL for each file path and using it to download the file.

### Code Snippets
```python
import json
import requests

# Pre-list file paths for each dataset repository
def pre_list_file_paths(repo_id, path):
    response = requests.get(f"https://huggingface.co/datasets/{repo_id}/tree/main/{path}")
    file_paths = response.json()
    return file_paths

# Embed file paths in training script
def embed_file_paths(file_paths, json_file):
    with open(json_file, "w") as f:
        json.dump(file_paths, f)

# Use CDN for dataset downloads
def download_dataset_file(file_path):
    cdn_url = f"https://huggingface.co/datasets/{file_path}"
    response = requests.get(cdn_url)
    return response.content

# Example usage
repo_id = "example/repo"
path = "path/to/dataset"
file_paths = pre_list_file_paths(repo_id, path)
embed_file_paths(file_paths, "file_paths.json")

# In training script
with open("file_paths.json", "r") as f:
    file_paths = json.load(f)

for file_path in file_paths:
    dataset_file = download_dataset_file(file_path)
    # Use dataset file for training
```
This implementation plan and code snippets provide a starting point for optimizing the frontend of the airship project by implementing a CDN bypass for dataset training.
