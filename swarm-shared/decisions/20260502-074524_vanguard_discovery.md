# vanguard / discovery

### 1. **Diagnosis**
* The Vanguard project lacks a comprehensive solution to handle HF API rate limits, which can block dataset training and hinder the project's progress.
* The current implementation does not utilize the HF CDN bypass strategy, which can download public dataset files without being limited by the HF API rate limits.
* The project's training pipeline is not optimized for performance, leading to potential bottlenecks and inefficiencies.
* The project's codebase lacks a clear and consistent structure, making it difficult to maintain and extend.
* The project's README file is missing, which can make it difficult for new contributors to understand the project's purpose and goals.

### 2. **Proposed change**
The proposed change is to implement the HF CDN bypass strategy in the training pipeline, which involves modifying the `train.py` file to download public dataset files from the HF CDN instead of using the HF API. This change will be made in the `/opt/axentx/vanguard/train.py` file, specifically in the `load_dataset` function.

### 3. **Implementation**
To implement the HF CDN bypass strategy, the following steps will be taken:
1. Modify the `load_dataset` function in `train.py` to download public dataset files from the HF CDN using the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern.
2. Use the `requests` library to download the dataset files from the HF CDN.
3. Parse the downloaded dataset files and load them into the training pipeline.
4. Update the `train.py` file to use the new `load_dataset` function.

Example code snippet:
```python
import requests

def load_dataset(repo, path):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{path}"
    response = requests.get(url)
    dataset = response.json()
    return dataset

# Usage
dataset = load_dataset("axentx/vanguard", "data/train.json")
```
### 4. **Verification**
To verify that the HF CDN bypass strategy is working correctly, the following steps will be taken:
1. Run the `train.py` file with the modified `load_dataset` function.
2. Check the dataset files are being downloaded from the HF CDN instead of the HF API.
3. Verify that the training pipeline is working correctly and that the dataset files are being loaded correctly.
4. Monitor the project's performance and efficiency to ensure that the HF CDN bypass strategy is improving the project's overall performance.
