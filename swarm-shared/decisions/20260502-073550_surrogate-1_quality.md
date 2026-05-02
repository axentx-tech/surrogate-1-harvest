# surrogate-1 / quality

### Diagnosis
* The project lacks a robust implementation for handling Hugging Face API rate limits on the discovery side, which can block dataset training.
* The existing implementation may not be reusing existing Lightning Studio instances efficiently, leading to wasted resources.
* The project does not have a mechanism to handle mixed schema files in the dataset, which can cause errors during training.
* The project is not utilizing the HF CDN bypass to download dataset files, which can reduce the load on the API and improve training efficiency.
* The project is not properly handling Lightning idle stop, which can kill training processes and lead to wasted resources.

### Proposed change
The proposed change will focus on implementing a robust mechanism to handle Hugging Face API rate limits, reuse existing Lightning Studio instances, and handle mixed schema files in the dataset. The change will be implemented in the `train.py` file, which is responsible for training the model.

### Implementation
To implement the proposed change, the following steps will be taken:
1. Modify the `train.py` file to use the HF CDN bypass to download dataset files. This can be done by replacing the `load_dataset` function with a custom function that downloads the files from the HF CDN.
2. Implement a mechanism to handle mixed schema files in the dataset. This can be done by projecting the files to `{prompt, response}` only at parse time, and then uploading the projected files to the HF dataset.
3. Modify the `train.py` file to reuse existing Lightning Studio instances. This can be done by listing the existing studios and reusing the running ones.
4. Implement a mechanism to handle Lightning idle stop. This can be done by checking the status of the studio before each `.run()` call and restarting the studio if it is stopped.

Example code snippet:
```python
import os
import json
import requests
from lightning import Lightning

# Define a function to download dataset files from HF CDN
def download_dataset_files(repo, path):
    url = f"https://huggingface.co/datasets/{repo}/resolve/main/{path}"
    response = requests.get(url)
    return response.json()

# Define a function to project mixed schema files to {prompt, response}
def project_files(files):
    projected_files = []
    for file in files:
        # Project the file to {prompt, response}
        projected_file = {"prompt": file["prompt"], "response": file["response"]}
        projected_files.append(projected_file)
    return projected_files

# Define a function to reuse existing Lightning Studio instances
def reuse_studio(studio_name):
    studios = Lightning.studios()
    for studio in studios:
        if studio.name == studio_name and studio.status == "Running":
            return studio
    return None

# Define a function to handle Lightning idle stop
def handle_idle_stop(studio):
    if studio.status == "Stopped":
        studio.start(machine="L40S")

# Modify the train.py file to use the HF CDN bypass and reuse existing studios
def train():
    repo = "axentx/surrogate-1"
    path = "data/train.json"
    files = download_dataset_files(repo, path)
    projected_files = project_files(files)
    studio = reuse_studio("surrogate-1")
    if studio is None:
        studio = Lightning.studio("surrogate-1", create_ok=True)
    handle_idle_stop(studio)
    # Train the model using the projected files
    model = Lightning.model("surrogate-1", studio=studio)
    model.train(projected_files)

# Run the train function
train()
```
### Verification
To verify that the proposed change works, the following steps can be taken:
1. Run the `train.py` file and verify that the model is trained successfully using the projected files.
2. Check the HF API rate limits and verify that the HF CDN bypass is being used to download dataset files.
3. Verify that existing Lightning Studio instances are being reused and that new instances are not being created unnecessarily.
4. Verify that the mechanism to handle mixed schema files is working correctly and that the projected files are being used to train the model.
5. Verify that the mechanism to handle Lightning idle stop is working correctly and that the studio is being restarted if it is stopped.
