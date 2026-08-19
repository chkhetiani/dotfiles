#!/bin/bash
# convert_xlsm_to_xlsx.sh
# Converts High/Low .xlsm files in current directory to xlsx via LibreOffice,
# saved one directory up as high.xlsx and low.xlsx

shopt -s nocaseglob

for f in *.xlsm; do
    [ -e "$f" ] || continue

    fname_lower=$(echo "$f" | tr '[:upper:]' '[:lower:]')

    if [[ "$fname_lower" == *"high"* || "$fname_lower" == *"98"* ]]; then
        label="high"
    elif [[ "$fname_lower" == *"low"* || "$fname_lower" == *"79"* ]]; then
        label="low"
    else
        echo "Skipping (no high/low match): $f"
        continue
    fi

    echo "Converting: $f -> ../${label}.xlsx"

    # Convert to a temp xlsx first (LibreOffice names output after input file)
    tmpdir=$(mktemp -d)
    libreoffice --headless --convert-to xlsx --outdir "$tmpdir" "$f" > /dev/null

    converted=$(find "$tmpdir" -name "*.xlsx" | head -n 1)

    if [ -n "$converted" ]; then
        mv "$converted" "../${label}.xlsx"
    else
        echo "Conversion failed for: $f"
    fi

    rm -rf "$tmpdir"
done

shopt -u nocaseglob
echo "Done."
