#!/bin/bash

# Daniel Mendelson, 21 Aug 2024

source config.shlib

# Define paths
IN_CSV_PATH=$(config_get IN_CSV_PATH "/DEFAULT/IN/PATH/")
OUT_PATH=$(config_get OUT_PATH "/DEFAULT/OUT/PATH/")
OUT_NAME=$(config_get OUT_NAME "DEFAULT_OUT_NAME_")$(date +"%d%b%Y_%Hh%M")".csv"
OUT=$OUT_PATH"/"$OUT_NAME
LOG=$OUT_PATH"/log_"$(date +"%d%b%Y_%Hh%M")".txt"

# Define specific mask variables
# For each mask, create an associative array with the following elements: path, label_value. Key should be the label to be used in output header
declare -A MASK_PATHS
declare -A MASK_labelValues

MASK_PATHS[$(config_get MASK1_LABEL "MASK1")]=$(config_get MASK1_PATH "/DEFAULT/MASK1/PATH/")
MASK_PATHS[$(config_get MASK2_LABEL "MASK2")]=$(config_get MASK2_PATH "/DEFAULT/MASK2/PATH/")
MASK_PATHS[$(config_get MASK3_LABEL "MASK3")]=$(config_get MASK3_PATH "/DEFAULT/MASK3/PATH/")

# Define label values of mask file for specific mask region
MASK_labelValues[$(config_get MASK1_LABEL "MASK1")]=$(config_get MASK1_binValues 1)
MASK_labelValues[$(config_get MASK2_LABEL "MASK2")]=$(config_get MASK2_binValues 1)
MASK_labelValues[$(config_get MASK3_LABEL "MASK3")]=$(config_get MASK3_binValues 1)

# Define reference mask
REF_MASK=$(config_get REF_MASK "MASK3")

# Define column names of interest
ID=$(config_get ID "id")
VISIT=$(config_get VISIT "visit")
IMAGE_PATH=$(config_get IMAGE_PATH "nav_adni")
QC=$(config_get QC "nav_qc")

# Define image type
IMAGE_TYPE=$(config_get IMAGE_TYPE "NAV") # Specify label of image files of interest, for use in output columns. E.g., 'NAV' for NAV pet, 'T1' for T1-weighted MRI, etc. 

# Check if the input CSV file exists
if [ ! -f $IN_CSV_PATH ]; then
  
  echo -e "ERROR. Input CSV file not found. Check 'IN_CSV_PATH' in 'config.cfg'. \n\tPath: $IN_CSV_PATH\nExiting script." 2>&1 | tee -a "$LOG"
  exit 1

fi

# check if output directory exists
if [ ! -f "$OUT" ]; then
  if [ ! -f "$OUT_PATH" ]; then
  	mkdir -p $OUT_PATH
  	
  	# Ensure output directory is properly made
  	if [[ $? -eq 0 ]]; then
  		echo "Output directory created at $OUT_PATH" 2>&1 | tee -a "$LOG"
  	else
  		echo "Failed to create output directory. Ensure path of [OUT_PATH] variable exists and try again. Exiting script." 2>&1 | tee -a "$LOG"
  		exit 1
  	fi	
  fi
  
  if [ ! -f "$OUT_NAME" ]; then
  	touch $OUT
  	echo "Output file made at $OUT"
  fi
fi


# Get column number of above columns of interest
ID_colNum=$(awk -v header="$ID" -F, '
BEGIN { colnum = -1 }
NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i ~ header) {
            colnum = i
            break
        }
    }
    print colnum
}' "$IN_CSV_PATH")

VISIT_colNum=$(awk -v header="$VISIT" -F, '
BEGIN { colnum = -1 }
NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i ~ header) {
            colnum = i-1
            break
        }
    }
    print colnum
}' "$IN_CSV_PATH")

IMAGE_PATH_colNum=$(awk -v header="$IMAGE_PATH" -F, '
BEGIN { colnum = -1 }
NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i ~ header) {
            colnum = i-1
            break
        }
    }
    print colnum
}' "$IN_CSV_PATH")

QC_colNum=$(awk -v header="$QC" -F, '
BEGIN { colnum = -1 }
NR == 1 {
    for (i = 1; i <= NF; i++) {
        if ($i ~ header) {
            colnum = i-1
            break
        }
    }
    print colnum
}' "$IN_CSV_PATH")

if [[ $ID_colNum == "-1" ]] || [[ $VISIT_colNum == "-1" ]] || [[ $IMAGE_PATH_colNum == "-1" ]] || [[ $QC_colNum == "-1" ]]; then
	echo "One of specified column names does not exist. Ensure all column names are properly defined in config.cfg and try again."
	echo -e "\t$ID:$ID_colNum $VISIT:$VISIT_colNum $IMAGE_PATH:$IMAGE_PATH_colNum $QC:$QC_colNum"
	echo "Terminating script."
	exit 1
fi

# Initialize log. Print values for above variables to log.
echo -e "Log file for shell script that applies mincstats summary statistics to images in input csv with region of interest masks defined by .mnc masks.\nScript created by Daniel Mendelson, working under the supervision of Dr. Pedro Rosa-Neto.\nScript run at: $(date +"%d %b %Y, %H:%M:%S")" > "$LOG"
# Save values of variables to log
echo -e "\nVARIABLES\n\tIN_CSV_PATH:\t$IN_CSV_PATH\n\tOUT_PATH:\t$OUT_PATH\n\tOUT_NAME:\t$OUT_NAME\n\tOUT:\t$OUT\n\tMASK_PATHS:\t"${MASK_PATHS[@]}"\n\tMASK_labelValues:\t${MASK_labelValues[@]}\n\tREF_MASK:\t$REF_MASK\n\tColumn indices (one less than column number in input file): \n\t\t$ID:\t$ID_colNum\n\t\t$VISIT:\t$VISIT_colNum\n\t\t$IMAGE_PATH:\t$IMAGE_PATH_colNum\n\t\t$QC:\t$QC_colNum\n\tImage type = $IMAGE_TYPE" >> "$LOG"

# Check if the mask files exist
for MASK in "${!MASK_PATHS[@]}"; do
	#echo "Checking path for $MASK"
	
	if [ ! -f "${MASK_PATHS[$MASK]}" ]; then
	  echo "ERROR. Mask file not found for '$MASK'. Check definition of [MASK_PATHS]. Exiting script." 2>&1 | tee -a "$LOG"
	  echo "Path: ${MASK_PATHS[$MASK]}" 2>&1 | tee -a "$LOG"
	  exit 1
	fi
	
done

# Make column headers to output file
# Change according to options used in mincstats and change corresponding grep term as appropriate
headers="id,visit,"

# Make headers for each mask region
for KEY in "${!MASK_PATHS[@]}"; do
	
	COL1=$IMAGE_TYPE"_"$KEY"_mean"
	headers+="$COL1,"
	
	if [ ! $KEY == "$REF_MASK" ]; then
		COL2=$IMAGE_TYPE"_"$KEY"_mdn"
		COL3=$IMAGE_TYPE"_"$KEY"_max"
		COL4=$IMAGE_TYPE"_"$KEY"_min"
		COL5=$IMAGE_TYPE"_"$KEY"_std"
		headers+="$COL2,$COL3,$COL4,$COL5,"
	fi
	
done

headers=$(echo "$headers" | sed 's/,$//') # remove trailing ','
#echo $headers
echo $headers > "$OUT" # this will override files with this current output path

# iterate through input CSV lines, get PET scan, apply mincstats, add mincstats results to output file along with ID, and visit number

# define counters
counter=-1 # First row is headers, first image will be at counter 0
excluded_count=0
missing_path=0
missing_file=0
QC_excluded=0

while IFS=, read -r -a row; do # Iterate through input data sheet row by row

	# skip first iteration
	if [[ $counter -eq -1 ]]; then
		((counter++))
		continue
	fi

	ID=${row[$ID_colNum]} # should take value from MCSA sheet column named 'id' 
	VISIT=${row[$VISIT_colNum]} # should take value from MCSA sheet column named 'visit'
	IMAGE_PATH=${row[$IMAGE_PATH_colNum]} # should take value from MCSA sheet column named 'nav_adni' containing path to desired image
	QC=${row[$QC_colNum]} # should take value from MCSA sheet column named 'nav_qc
	
	#echo $IMAGE_PATH
	IMAGE_PATH=$(echo "$IMAGE_PATH" | sed 's/"//g')
	#echo $IMAGE_PATH
	
	#echo "ID: $ID, Visit: $VISIT, Image: $IMAGE_PATH"
	
	# If no path defined in input file, then continue
	if [[ -z $IMAGE_PATH ]] || [[ $IMAGE_PATH == "NA" ]]; then
		if [[ $excluded_count == 0 ]]; then
			echo -e "\nExcluding some participants. See below and log file." 2>&1 | tee -a "$LOG"
		fi
		
		((excluded_count++))
		((missing_path++))
		echo -e "\tID $ID\tvisit $VISIT: No image path defined in input CSV. Skipping this case." 2>&1 | tee -a "$LOG"
		continue
	fi
	
	# If path is defined in input file but file doesn't exist, then continue
	if [[ ! -f $IMAGE_PATH ]]; then 
		if [[ $excluded_count == 0 ]]; then
			echo -e "\nExcluding some participants. See below and log file." 2>&1 | tee -a "$LOG"
		fi
		
		((excluded_count++))
		((missing_file++))

		echo -e "\tID $ID\tvisit $VISIT: Image path defined in input CSV does not exist. Skipping this case. (Path: $IMAGE_PATH)" 2>&1 | tee -a "$LOG"
		continue
	fi
	
	# If QC column for image is 0, then continue
	if [[ $QC == "0" ]]; then
		if [[ $excluded_count == 0 ]]; then
			echo -e "\nExcluding some participants. See below and log file." 2>&1 | tee -a "$LOG"
		fi
		
		((excluded_count++))
		((QC_excluded++))
		echo -e "\tID $ID\tvisit $VISIT: Image QC = $QC. Case excluded. (Path: $IMAGE_PATH)" 2>&1 | tee -a "$LOG"
		continue
	fi
	
	output="$ID,$VISIT," # Add ID and visit of the current row to the output variable
	
	# Calculate MINCSTAT values for each mask
	for MASK in "${!MASK_PATHS[@]}"; do
		
		MASK_PATH=${MASK_PATHS[$MASK]}
		#echo "Mask: $MASK"
			if [ $MASK == $REF_MASK ]; then
				result=$(mincstats -mask $MASK_PATH -mask_binvalue ${MASK_labelValues[$MASK]} $IMAGE_PATH -mean)
				echo "$results"
				COL1=$(echo "$result" | grep "Mean:" | awk '{print $2}')
				output+="$COL1,"
			else
				# Calculate PET values of interest with mincstats, save to variable
				result=$(mincstats -mask $MASK_PATH -mask_binvalue ${MASK_labelValues[$MASK]} $IMAGE_PATH -mean -median -min -max -std)
				echo "$results"
		
				# extract mincstats outputs into variables
				COL1=$(echo "$result" | grep "Mean:" | awk '{print $2}')
				COL2=$(echo "$result" | grep "Median:" | awk '{print $2}')
				COL3=$(echo "$result" | grep "Max:" | awk '{print $2}')
				COL4=$(echo "$result" | grep "Min:" | awk '{print $2}')
				COL5=$(echo "$result" | grep "Stddev:" | awk '{print $2}')
				output+="$COL1,$COL2,$COL3,$COL4,$COL5,"
			fi
			
	done

	# Save values to outputfile
	headers=$(echo "$headers" | sed 's/,$//') # remove trailing ','
	echo $output >> $OUT

	((counter++))

done < "$IN_CSV_PATH"

echo -e "\nPerformed operations on $counter images. Excluded $excluded_count cases:\n\tImage path not defined: $missing_path\n\tNo file at path: $missing_file\n\tImage QC is 0: $QC_excluded" 2>&1 | tee -a "$LOG"
echo -e "\nOutputs saved to:\n\tMain data:\t$OUT\n\tlog:\t\t$LOG" 2>&1 | tee -a "$LOG"
echo -e "\nEnd time: $(date +"%d %b %Y, %H:%M:%S")" >> "$LOG"

