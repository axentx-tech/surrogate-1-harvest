# surrogate-1 / discovery

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits on the discovery side, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources.
* The project can benefit from optimizing the dataset ingestion process to reduce the load on the Hugging Face API.

### Proposed change
The proposed change is to implement a CDN bypass for dataset training to reduce the load on the Hugging Face API. This can be achieved by modifying the `train.py` script to download dataset files directly from the Hugging Face CDN instead of using the API.

### Implementation
To implement the CDN bypass, follow these steps:
1. Modify the `train.py` script to use the `hf_hub_download` function to download dataset files directly from the Hugging Face CDN.
2. Update the `train.py` script to use the `list_repo_tree` function to get the list of dataset files instead of using the `list_repo_files` function.
3. Use the `requests` library to download the dataset files from the Hugging Face CDN.

Example code snippet:
```python
import requests
from huggingface_hub import hf_hub_download

# Get the list of dataset files
repo_id = "your-repo-id"
dataset_files = hf_hub_download(repo_id, repo_type="dataset", filename="files.json")

# Download the dataset files from the Hugging Face CDN
for file in dataset_files:
    file_url = f"https://huggingface.co/datasets/{repo_id}/resolve/main/{file}"
    response = requests.get(file_url)
    with open(file, "wb") as f:
        f.write(response.content)
```
### Verification
To verify that the CDN bypass is working correctly, follow these steps:
1. Run the modified `train.py` script and check that the dataset files are being downloaded correctly from the Hugging Face CDN.
2. Monitor the Hugging Face API usage and check that the number of API calls has decreased.
3. Verify that the dataset training process is completing successfully and that the model is being trained correctly.
