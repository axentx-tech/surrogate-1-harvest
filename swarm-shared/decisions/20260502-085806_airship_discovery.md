# airship / discovery

### Highest-Value Incremental Improvement
The highest-value incremental improvement that can be shipped in <2h is to implement the HF CDN Bypass pattern to avoid rate-limit blocks during dataset training. This involves downloading public dataset files from the HF CDN without using the HF API, which has a separate and higher rate limit.

### Implementation Plan
1. **Identify the dataset**: Determine which dataset is being used for training and identify its repository and file path.
2. **Modify the training script**: Update the training script to download the dataset files from the HF CDN using the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern.
3. **Embed the file list**: Pre-list the file paths once and embed them in the training script to avoid making API calls during data loading.
4. **Use the CDN-only fetches**: Modify the training script to use CDN-only fetches with zero API calls during data loading.

### Code Snippets
```python
import requests

# Define the dataset repository and file path
repo = "dataset/repo"
file_path = "path/to/file"

# Download the dataset file from the HF CDN
url = f"https://huggingface.co/datasets/{repo}/resolve/main/{file_path}"
response = requests.get(url)

# Save the file to a local directory
with open(f"{file_path}", "wb") as f:
    f.write(response.content)
```

### Example Use Case
To train a model using the `dataset/repo` dataset, the training script can be modified to download the dataset files from the HF CDN as follows:
```python
import os
import requests

# Define the dataset repository and file path
repo = "dataset/repo"
file_path = "path/to/file"

# Download the dataset file from the HF CDN
url = f"https://huggingface.co/datasets/{repo}/resolve/main/{file_path}"
response = requests.get(url)

# Save the file to a local directory
with open(f"{file_path}", "wb") as f:
    f.write(response.content)

# Load the dataset and train the model
# ...
```
This implementation plan and code snippets provide a concrete example of how to implement the HF CDN Bypass pattern to avoid rate-limit blocks during dataset training.
