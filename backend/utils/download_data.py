import gdown
import os
import zipfile

FOLDER_ID = '1AID1Rw4Kf6WMZjX9OrNCwcUIkRFiWGfo'
OUTPUT_FOLDER_NAME = 'files_from_drive_folder'

if not os.path.exists(OUTPUT_FOLDER_NAME):
    os.makedirs(OUTPUT_FOLDER_NAME)
    print(f"Created directory: {OUTPUT_FOLDER_NAME}")

print(f"Starting download of folder with ID: {FOLDER_ID}...")
gdown.download_folder(id=FOLDER_ID, output=OUTPUT_FOLDER_NAME, quiet=False)

print(f"Download process completed into directory: {OUTPUT_FOLDER_NAME}")

# Extract any zip files in the downloaded folder
for root, dirs, files in os.walk(OUTPUT_FOLDER_NAME):
    for file in files:
        if file.endswith('.zip'):
            zip_path = os.path.join(root, file)
            extract_path = os.path.splitext(zip_path)[0]
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_path)
            print(f"Extracted {zip_path} to {extract_path}")
