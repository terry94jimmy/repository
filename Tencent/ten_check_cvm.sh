#!/bin/bash

JSON="output.json"
REGIONS=("ap-guangzhou" "ap-shanghai" "ap-beijing" "ap-hongkong" "ap-singapore" "ap-nanjing")


if [[ ! -f $JSON ]]; then
    echo "no json"
    exit 1

fi

    jq -r 'to_entries[] | "\(.key) \(.value.secretid) \(.value.secretkey)"' "$JSON" | 

while read key secretid secretkey;do
    if [[ -z "$key" || -z "$secretid" || -z "$secretkey" ]];then
    echo "value null"
    exit 1
    fi
    export TENCENTCLOUD_SECRET_ID="$secretid"
    export TENCENTCLOUD_SECRET_KEY="$secretkey"
    output_file="${key}.cvm.txt"
    #> $output_file

    echo "account check $key"

           for region in "${REGIONS[@]}"; do
        echo "Checking region: $region"

        cvm_list=$(tccli cvm DescribeInstances --region $region --output json | jq -r '.InstanceSet[] | "\(.InstanceId) \(.InstanceName) \(.InstanceState) \(.PublicIpAddresses) \(.Placement.Zone)"')
    while read -r InstanceId InstanceName InstanceState PublicIpAddresses Zone; do
        if [[ -z "$InstanceId" || -z "$InstanceName" || -z "$InstanceState" || -z "$PublicIpAddresses" || -z  "$Zone" ]]; then
            echo "Skipping empty load balancer entry"
            continue
        fi
        echo -e "account: $key\t Instance ID: $InstanceId\t Instance Name: $InstanceName\t Status: $InstanceState\t IP: $PublicIpAddresses\t Region: $Zone" >> "$output_file"
        done <<< "$cvm_list"
    done

done