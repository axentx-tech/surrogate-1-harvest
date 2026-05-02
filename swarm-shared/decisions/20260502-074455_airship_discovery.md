# airship / discovery

### Highest-Value Incremental Improvement
The highest-value incremental improvement that can ship in <2h is to implement the HF CDN Bypass pattern to avoid API rate limits when downloading dataset files. This can be achieved by modifying the `train.py` script to download dataset files directly from the HF CDN using the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern.

### Implementation Plan
1. **Identify the dataset repository and file paths**:
	* Use the `list_repo_tree` API call to retrieve the list of file paths for the desired dataset repository.
	* Save the list of file paths to a JSON file.
2. **Modify the `train.py` script**:
	* Import the `requests` library to download files from the HF CDN.
	* Use the `https://huggingface.co/datasets/{repo}/resolve/main/{path}` URL pattern to download dataset files directly from the HF CDN.
	* Remove any API calls that are no longer necessary.
3. **Test the modified `train.py` script**:
	* Run the modified `train.py` script to ensure that it can download dataset files successfully from the HF CDN.

### Code Snippets
```python
import requests
import json

# Load the list of file paths from the JSON file
with open('file_paths.json', 'r') as f:
    file_paths = json.load(f)

# Download dataset files directly from the HF CDN
for file_path in file_paths:
    url = f'https://huggingface.co/datasets/{repo}/resolve/main/{file_path}'
    response = requests.get(url)
    with open(file_path, 'wb') as f:
        f.write(response.content)
```
Note: Replace `{repo}` with the actual dataset repository name.

### Benefits
The HF CDN Bypass pattern provides several benefits, including:

* Avoids API rate limits when downloading dataset files.
* Reduces the number of API calls required to download dataset files.
* Improves the overall performance and efficiency of the training process.
