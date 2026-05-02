# surrogate-1 / frontend

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits on the frontend side, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources.
* The frontend does not have a mechanism to bypass the Hugging Face API rate limit by using the CDN tier for dataset downloads.
* The project does not have a clear strategy for handling mixed schema files in the dataset, which can cause errors during training.
* The frontend does not have a way to check the status of Lightning Studio instances before running training scripts, which can lead to idle timeouts.

### Proposed change
The proposed change will focus on implementing a mechanism to bypass the Hugging Face API rate limit by using the CDN tier for dataset downloads. This will involve modifying the `train.py` script to download dataset files from the CDN instead of using the Hugging Face API.

### Implementation
To implement this change, we will need to modify the `train.py` script to use the CDN tier for dataset downloads. We can do this by replacing the `load_dataset` function with a custom function that downloads the dataset files from the CDN.

```python
import json
import requests

def download_dataset_from_cdn(repo_id, path):
    # Get the list of files in the dataset
    file_list_url = f"https://huggingface.co/datasets/{repo_id}/resolve/main/{path}"
    response = requests.get(file_list_url)
    file_list = response.json()

    # Download each file from the CDN
    dataset_files = []
    for file in file_list:
        file_url = f"https://huggingface.co/datasets/{repo_id}/resolve/main/{path}/{file}"
        response = requests.get(file_url)
        dataset_files.append(response.content)

    return dataset_files

# Replace the load_dataset function with our custom function
dataset_files = download_dataset_from_cdn("repo_id", "path")
```

We will also need to modify the `train.py` script to reuse existing Lightning Studio instances efficiently. We can do this by adding a check to see if a studio instance is already running before creating a new one.

```python
import lightning

def get_studio_instance(studio_name):
    # Get the list of running studio instances
    studios = lightning.Teamspace.studios

    # Check if a studio instance with the given name is already running
    for studio in studios:
        if studio.name == studio_name and studio.status == "Running":
            return studio

    # If no studio instance is found, create a new one
    return lightning.Studio(create_ok=True)

# Replace the studio creation code with our custom function
studio = get_studio_instance("studio_name")
```

### Verification
To verify that the changes work, we can run the `train.py` script and check that the dataset files are being downloaded from the CDN instead of the Hugging Face API. We can also check that the studio instance is being reused efficiently by checking the list of running studio instances.

We can add some logging statements to the `train.py` script to verify that the changes are working as expected.

```python
print("Downloading dataset files from CDN...")
dataset_files = download_dataset_from_cdn("repo_id", "path")
print("Dataset files downloaded successfully!")

print("Getting studio instance...")
studio = get_studio_instance("studio_name")
print("Studio instance obtained successfully!")
```

By running the `train.py` script and checking the output, we can verify that the changes are working as expected.
