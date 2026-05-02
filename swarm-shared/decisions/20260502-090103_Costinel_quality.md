# Costinel / quality

### Highest-Value Incremental Improvement
Based on the provided patterns and lessons learned, the highest-value incremental improvement that can ship in <2h is to implement the HF CDN Bypass pattern to avoid API rate limits when downloading dataset files.

### Implementation Plan
1. **Identify dataset files**: Pre-list file paths once using the `list_repo_tree` API call with `recursive=False` for one date folder.
2. **Save file list to JSON**: Embed the file list in the training script `train.py`.
3. **Use CDN-only fetches**: Modify the training script to download dataset files from the HF CDN using the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern, bypassing the API rate limit.

### Code Snippets
```python
import json
import requests

# Pre-list file paths using list_repo_tree API call
def get_file_list(repo, path):
    url = f"https://huggingface.co/api/v1/datasets/{repo}/tree?path={path}&recursive=False"
    response = requests.get(url)
    file_list = response.json()["files"]
    return file_list

# Save file list to JSON
file_list = get_file_list("my-repo", "my-path")
with open("file_list.json", "w") as f:
    json.dump(file_list, f)

# Use CDN-only fetches in train.py
import json

with open("file_list.json", "r") as f:
    file_list = json.load(f)

for file in file_list:
    url = f"https://huggingface.co/datasets/my-repo/resolve/main/{file}"
    response = requests.get(url)
    # Process the downloaded file
```
This implementation plan and code snippets demonstrate how to apply the HF CDN Bypass pattern to avoid API rate limits when downloading dataset files, allowing for faster and more efficient training.
