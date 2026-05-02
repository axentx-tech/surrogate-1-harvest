# surrogate-1 / discovery

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits on the discovery side, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources.
* The project does not have a mechanism to bypass the Hugging Face API rate limit for dataset training, which can cause delays and inefficiencies.

### Proposed change
The proposed change is to implement a mechanism to bypass the Hugging Face API rate limit for dataset training by using the Hugging Face CDN to download dataset files. This can be achieved by modifying the `train.py` script to use the CDN URL for downloading dataset files instead of the API.

### Implementation
To implement this change, follow these steps:
1. Modify the `train.py` script to use the Hugging Face CDN URL for downloading dataset files.
2. Use the `hf_hub_download` function to download dataset files from the CDN.
3. Update the `train.py` script to use the downloaded dataset files for training.

Example code snippet:
```python
import os
from huggingface_hub import hf_hub_download

# Define the dataset repository and file path
repo_id = "dataset/repo"
file_path = "path/to/file"

# Download the dataset file from the CDN
cdn_url = f"https://huggingface.co/{repo_id}/resolve/main/{file_path}"
file_path = hf_hub_download(repo_id, file_path, repo_type="dataset", use_auth_token=False)

# Use the downloaded dataset file for training
train_data = ...
```
### Verification
To verify that the change works, follow these steps:
1. Run the modified `train.py` script and check if the dataset files are downloaded successfully from the CDN.
2. Verify that the training process completes without any errors related to the Hugging Face API rate limit.
3. Check the resource usage and verify that the change has improved the efficiency of the training process.
