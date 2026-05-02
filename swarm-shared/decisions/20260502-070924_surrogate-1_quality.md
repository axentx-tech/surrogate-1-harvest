# surrogate-1 / quality

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources.
* The project does not have a mechanism to bypass the Hugging Face API rate limit for dataset training.
* The implementation of the surrogate-1 training pipeline may be affected by the pyarrow CastError on HF datasets with mixed schema files.
* The project does not have a clear strategy for handling Lightning idle stop kills training.

### Proposed change
The proposed change is to implement a mechanism to bypass the Hugging Face API rate limit for dataset training by using the HF CDN bypass pattern. This involves pre-listing file paths once, embedding them in the training script, and using the CDN to download dataset files without making API calls.

### Implementation
To implement this change, we need to modify the `train.py` script to use the HF CDN bypass pattern. Here are the steps:
1. Run a single API call from the Mac to `list_repo_tree(path, recursive=False)` for one date folder.
2. Save the list of file paths to a JSON file.
3. Modify the `train.py` script to read the list of file paths from the JSON file and use the CDN to download dataset files.
4. Use the `hf_hub_download` function to download each file individually and project to {prompt, response} only at parse time.

Example code snippet:
```python
import json
import os

# Load the list of file paths from the JSON file
with open('file_paths.json', 'r') as f:
    file_paths = json.load(f)

# Use the CDN to download dataset files
for file_path in file_paths:
    file_url = f"https://huggingface.co/datasets/{repo}/resolve/main/{file_path}"
    # Download the file using the CDN
    os.system(f"wget {file_url}")
```
### Verification
To verify that the implementation works, we can check the following:
1. The `train.py` script can download dataset files using the CDN without making API calls.
2. The script can handle Hugging Face API rate limits by bypassing the API and using the CDN.
3. The implementation does not affect the performance of the surrogate-1 training pipeline.
4. The project can reuse existing Lightning Studio instances efficiently and avoid wasted resources.

We can verify these points by running the `train.py` script and checking the logs for any errors or issues related to the Hugging Face API rate limit or the CDN download. We can also check the performance of the surrogate-1 training pipeline and the reuse of existing Lightning Studio instances.
