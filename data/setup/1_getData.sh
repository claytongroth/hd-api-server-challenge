#!/usr/bin/env bash

set -euo pipefail

# List of the year+Q combinations to download
YEAR_QUARTERS_TO_DOWNLOAD=(Q1_2026 Q4_2025)

echo "Downloading and unzipping the Backblaze Hard Drive Data..."
echo "Grabbing the following year+Q combinations: ${YEAR_QUARTERS_TO_DOWNLOAD[@]}"

# Clear the old CSVs up front so we never hold two full copies at once
mkdir -p ../csv_data
rm -f ../csv_data/*.csv

# Loop through the year+Q combinations
for year_quarter in "${YEAR_QUARTERS_TO_DOWNLOAD[@]}"; do
    # Download the zip file
    curl -O https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_${year_quarter}.zip

    # Unzip the zip file (-o so a re-run doesn't stop to ask)
    unzip -o data_${year_quarter}.zip

    # Drop the zip as soon as it's extracted
    rm -f data_${year_quarter}.zip
done

echo "Data downloaded and unzipped successfully!"

echo "Moving CSV files into a csv_data directory..."
# Files will be in `data_Q1_2026/*.csv` and `data_Q4_2025/*.csv`
# Move CSV files into a better layout/strucutre `../csv_data`
mv data_Q1_2026/*.csv ../csv_data
mv data_Q4_2025/*.csv ../csv_data

# Drop the now-empty extract dirs
for year_quarter in "${YEAR_QUARTERS_TO_DOWNLOAD[@]}"; do
    rm -rf data_${year_quarter}
done

# Print summary of total count of moved files
echo "Total number of CSV files moved: $(ls -1 ../csv_data/*.csv | wc -l)"
