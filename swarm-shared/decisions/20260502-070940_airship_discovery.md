# airship / discovery

### Highest-Value Incremental Improvement
The highest-value incremental improvement that can be made to the airship project in under 2 hours is to optimize the Surrogate AI service's dataset ingestion process by utilizing the HF CDN bypass pattern. This involves pre-listing file paths once, embedding them in the training script, and using the CDN to download dataset files without hitting the HF API rate limit.

### Implementation Plan
1. **Identify Dataset Repositories**: Determine which dataset repositories are being used by the Surrogate AI service.
2. **Pre-list File Paths**: Use the HF API to pre-list file paths for each dataset repository. This can be done using the `list_repo_tree` method with `recursive=False`.
3. **Embed File Paths in Training Script**: Embed the pre-listed file paths in the training script to allow for CDN-only fetches during data loading.
4. **Update Training Script**: Update the training script to use the CDN to download dataset files instead of relying on the HF API.

### Code Snippets
```bash
# Pre-list file paths using HF API
hf_api_list_repo_tree.py
```

```python
import json
import requests

# Pre-list file paths for each dataset repository
def pre_list_file_paths(repo_id, path):
    url = f"https://huggingface.co/api/repo/{repo_id}/tree/{path}"
    response = requests.get(url)
    file_paths = response.json()["files"]
    return file_paths

# Embed file paths in training script
def embed_file_paths_in_training_script(file_paths):
    with open("train.py", "r+") as f:
        lines = f.readlines()
        f.seek(0)
        f.write("file_paths = {}\n".format(json.dumps(file_paths)))
        f.writelines(lines)
        f.truncate()

# Update training script to use CDN
def update_training_script():
    with open("train.py", "r+") as f:
        lines = f.readlines()
        f.seek(0)
        for line in lines:
            if "hf_api_download" in line:
                f.write(line.replace("hf_api_download", "cdn_download"))
            else:
                f.write(line)
        f.truncate()
```

```python
# Example usage
repo_id = "dataset/repo"
path = "path/to/dataset"
file_paths = pre_list_file_paths(repo_id, path)
embed_file_paths_in_training_script(file_paths)
update_training_script()
```

### Benefits
This improvement will allow the Surrogate AI service to ingest datasets more efficiently, reducing the likelihood of hitting the HF API rate limit and improving overall performance.
