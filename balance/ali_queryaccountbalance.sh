#!/bin/bash

json_file="sample.json"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

output_file="balance_report_$timestamp.txt"


echo "Balance Report - $timestamp" > "$output_file"
echo "----------------------------" >> "$output_file"


jq -c 'to_entries[]' "$json_file"| while read -r account; do
  
    name=$(echo "$account" | jq -r '.key')
    access_key_id=$(echo "$account" | jq -r '.value.ACCESS_KEY_ID')
    access_key_secret=$(echo "$account" | jq -r '.value.SECERT_KEY')

 
    aliyun configure set --profile "$name" --access-key-id "$access_key_id" --access-key-secret "$access_key_secret" > /dev/null 2>&1


    balance=$(aliyun bssopenapi QueryAccountBalance --profile "$name" | jq -r '.Data.AvailableAmount')


    if [[ "$balance" != "null" ]]; then
        echo "$name: $balance" | tee -a "$output_file"
    else
        echo "$name: Query failed" | tee -a "$output_file"
    fi
done


echo "Report generated: $output_file"
