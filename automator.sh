#!/bin/bash

# Default values for different variables
USER="adityakumar"
SCAN_PATH="/iplant/home/shared/phytooracle/season_15_lettuce_yr_2022/level_0/scanner3DTop/scanner3DTop-2023-03-07__18-27-40-989_lettuce.tar.gz"
TEST_DATASET_NAME="scanner3DTop-2223-03-07__00-00-00-000_lettuce.tar.gz"
NUMBER_OF_FILES=90

# Check for the values of different flags
while test $# -gt 0; do
  case "$1" in
  -h | --help)
    echo "script usage: $(basename $0) -p [pathname] -u [username] -t [test_dataset_name(DON'T INCLUDE .tar.gz)] -n [number_of_files]"
    echo "example: ./automator.sh -p /iplant/home/shared/phytooracle/season_16_sorghum_yr_2023/level_0/stereoTop/stereoTop-2223-05-08__00-00-00-000_sorghum.tar.gz -u ak -n 10 -t subset"
    echo "Check the github repo for more information."
    exit 0
    ;;
  -u)
    shift
    USER=$1
    shift
    ;;
  -p)
    shift
    SCAN_PATH=$1
    shift
    ;;
  -t)
    shift
    TEST_DATASET_NAME=$1
    shift
    ;;
  -n)
    shift
    NUMBER_OF_FILES=$1
    shift
    ;;
  *)
    echo "script usage: $(basename $0) -p [pathname] -u [username] -t [test_dataset_name(DON'T INCLUDE .tar.gz)] -n [number_of_files]" >&2
    exit 1
    ;;
  esac
done

# Processing to find the file name from the path provided and the directory name
SCAN_FILE_NAME=$(echo ${SCAN_PATH} | cut -d '/' -f 9)
SCAN_DIR_NAME=$(echo ${SCAN_FILE_NAME} | cut -d '.' -f 1)

# Download the file
if ! ssh filexfer "cd /xdisk/dukepauli/${USER}/;iget -KT ${SCAN_PATH}"; then
  echo "Error: Failed to download file from remote server." >&2
  exit 1
fi

echo "Scan ${SCAN_FILE_NAME} download complete. (1/5)"

# Extract the scan from the downloaded zip
if ! tar -xzvf ${SCAN_FILE_NAME}; then
  echo "Error: Failed to extract file." >&2
  exit 1
fi

echo "File extraction done. (2/5)"

# Main section to choose the sub-directories from the middle of the scan
echo "Selecting files for the test dataset. (3/5)"
mkdir ${TEST_DATASET_NAME}
cd ${SCAN_DIR_NAME}
FILE_COUNT=$(ls | wc -l)
# For scans with even numbered files
if [ $((FILE_COUNT % 2)) -eq 0 ]; then
  ls | head -n $((($FILE_COUNT + 1) / 2 + $NUMBER_OF_FILES / 2)) | tail -n ${NUMBER_OF_FILES} | xargs -I {} cp {} "../${TEST_DATASET_NAME}/"
else
  ls | head -n $((($FILE_COUNT + 1) / 2 + $NUMBER_OF_FILES / 2)) | tail -n $((NUMBER_OF_FILES + 1)) | xargs -I {} cp {} "../${TEST_DATASET_NAME}/"
fi

# To go inside the newly created test dataset and remove garbage files
cd ../${TEST_DATASET_NAME}
rm -f *.json *.bin

# Zip and post the test dataset
echo "Zipping and uploading the test dataset. (4/5)"
if ! tar -czvf "${TEST_DATASET_NAME}.tar.gz" "${TEST_DATASET_NAME}/"; then
  echo "Error: Failed to create tarball of test dataset." >&2
  exit 1
fi

if ! ssh filexfer "cd /xdisk/dukepauli/${USER}/;iput -KT '${TEST_DATASET_NAME}.tar.gz'"; then
  echo "Error: Failed to upload test dataset to remote server." >&2
  exit 1
fi

echo "Done. (5/5)"
