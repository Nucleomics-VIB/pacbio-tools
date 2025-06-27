#!/bin/bash
# filepath: /Users/u0002316/Documents/GitHub/Nucleomics-VIB/pacbio-tools/smrtlink-tools/16S_rerun_simulator2.sh

# Usage:
# ./16S_rerun_simulator2.sh -f /path/to/folder -m 100000 -p "Experiment_001"

# Default values
FOLDER=""
MAXVALUE=100000
PROJECT="Unknown"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--folder) FOLDER="$(cd "$2" && pwd)"; shift ;;
        -m|--maxvalue) MAXVALUE="$2"; shift ;;
        -p|--project) PROJECT="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 -f <folder> [-m <maxvalue>] [-p <project>]"
            exit 0
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$FOLDER" ]]; then
    echo "Error: Folder is required. Use -f <folder>"
    exit 1
fi

if [[ ! -d "$FOLDER" ]]; then
    echo "Error: Folder does not exist: $FOLDER"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RMD_PATH="$SCRIPT_DIR/16S_rerun_simulator2.Rmd"

# Set output HTML path
OUTPUT_HTML="$FOLDER/simulation_report_${PROJECT}.html"

# Render the R Markdown report with parameters and output file
Rscript -e "rmarkdown::render('$RMD_PATH', params=list(folder='$FOLDER', max_value=$MAXVALUE, project_id='$PROJECT'), output_file='$OUTPUT_HTML')"