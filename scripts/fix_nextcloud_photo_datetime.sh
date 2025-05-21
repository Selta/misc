#!/bin/bash

# NextCloud has an annoying issue where it (sometimes?) uses the system Modified datetime for organizing photos
# This is a problem in many cases, especially when doing a bulk upload of years of photos
# This script will "fix" the system Modified datetime to match one of the created datetime stamps from EXIF

# This script only requires the external tool "exif", which can be installed with your pacakage manager (eg. "sudo apt-get install exif")

# Usage: ./update_jpg_dates.sh /path/to/directory/with/photos

# Check if exif tool is installed
if ! command -v exif &> /dev/null; then
    echo "Error: 'exif' command not found. Please install it first:"
    echo "  For Ubuntu/Debian: sudo apt-get install exif"
    echo "  For macOS: brew install exif"
    exit 1
fi

# File processor
process_file() {
    local file="$1"
    
    # Skip non-jpg/jpeg files (case insensitive check)
    if [[ ! "${file,,}" =~ \.(jpg|jpeg)$ ]]; then
        echo "Skipping non-JPG file: $file"
        return
    fi
    
    # Check if file exists and is readable
    if [ ! -r "$file" ]; then
        echo "Error: Cannot read file $file"
        return
    fi
    
    echo "Processing: $file"
    
    # Try to extract DateTime field from EXIF data
    # Format is typically: "YYYY:MM:DD HH:MM:SS"
    exif_date=$(exif -t 0x9003 -m "$file" 2>/dev/null)
    
    # If DateTime not found, try Date and Time Original field
    if [ -z "$exif_date" ]; then
        exif_date=$(exif -t 0x9004 -m "$file" 2>/dev/null)
    fi
    
    # If still no date found, try DateTime field
    if [ -z "$exif_date" ]; then
        exif_date=$(exif -t 0x0132 -m "$file" 2>/dev/null)
    fi
    
    # Check if we got a date
    if [ -z "$exif_date" ]; then
        echo "  No EXIF date found for $file"
        return
    fi
    
    # Convert EXIF date format (YYYY:MM:DD HH:MM:SS) to format for touch command
    # touch expects: YYYYMMDDhhmm.ss
    converted_date=$(echo "$exif_date" | sed 's/[: ]//g' | sed 's/\(.\{12\}\)/\1./')
    
    echo "  EXIF date: $exif_date"
    echo "  Setting modification time..."
    
    # Update file modification time
    if touch -t "$converted_date" "$file"; then
        echo "  Success: Updated modification time for $file"
    else
        echo "  Error: Failed to update modification time for $file"
    fi
}

# LFG
if [ -z "$1" ]; then
    # No arguments, process current directory only
    echo "No directory specified. Processing current directory."
    dir="."
elif [ -d "$1" ]; then
    # Directory argument provided
    dir="$1"
else
    echo "Error: $1 is not a valid directory"
    echo "Usage: $0 [directory]"
    exit 1
fi

# Find all JPG files in the specified directory (recursive)
echo "Scanning for JPG files in: $dir"
find "$dir" -type f -iname "*.jpg" -o -iname "*.jpeg" | while read -r file; do
    process_file "$file"
done

echo "Processing complete."
