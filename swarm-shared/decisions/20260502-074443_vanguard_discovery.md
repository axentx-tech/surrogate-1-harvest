# vanguard / discovery

### 1. **Diagnosis**
* The Vanguard project lacks a comprehensive solution to handle HF API rate limits, which can block dataset training and hinder the project's progress.
* The current implementation does not utilize the HF CDN bypass strategy, which can download public dataset files without being subject to the same rate limits as the HF API.
* The project's training pipeline is not optimized to take advantage of the HF CDN bypass strategy, resulting in potential rate limit issues and decreased training efficiency.
* The project's codebase does not include a clear and concise implementation of the HF CDN bypass strategy, making it difficult to integrate and maintain.
* The project's training scripts do not include a mechanism to handle rate limit errors and retry failed requests, leading to potential training interruptions and decreased overall efficiency.

### 2. **Proposed change**
The proposed change will focus on implementing the HF CDN bypass strategy in the training pipeline. This will involve modifying the `train.py` script to download public dataset files from the HF CDN instead of using the HF API. The scope of the change will be limited to the `train.py` script and will not affect other parts of the project.

### 3. **Implementation**
To implement the HF CDN bypass strategy, the following steps will be taken:
1. Modify the `train.py` script to use the `hf_hub_download` function to download public dataset files from the HF CDN.
2. Update the `train.py` script to use the `list_repo_tree` function to retrieve a list of files in the dataset repository, instead of using the `list_repo_files` function.
3. Implement a retry mechanism to handle rate limit errors and retry failed requests.
4. Update the `train.py` script to use the `requests` library to download files from the HF CDN, instead of using the HF API.

Example code snippet:
```python
import requests
from huggingface_hub import Repository

# Define the dataset repository and file path
repo_id = "dataset/repo"
file_path = "path/to/file"

# Retrieve a list of files in the dataset repository
repo = Repository(repo_id)
files = repo.list_repo_tree(path=file_path, recursive=False)

# Download files from the HF CDN
for file in files:
    file_url = f"https://huggingface.co/{repo_id}/resolve/main/{file}"
    response = requests.get(file_url)
    with open(file, "wb") as f:
        f.write(response.content)
```
### 4. **Verification**
To verify that the implementation is working correctly, the following steps will be taken:
1. Run the modified `train.py` script and verify that it downloads the public dataset files from the HF CDN without encountering rate limit errors.
2. Monitor the training pipeline and verify that it is able to train models without interruptions due to rate limit errors.
3. Verify that the retry mechanism is working correctly by simulating a rate limit error and verifying that the script retries the failed request.
4. Compare the training time and efficiency before and after the implementation of the HF CDN bypass strategy to verify that it has improved the overall efficiency of the training pipeline.
