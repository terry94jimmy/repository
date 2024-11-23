#!/bin/bash


JSON="/home/user/git/jimmytest/test/ten/ten.json"
#REGIONS=("ap-guangzhou" "ap-shanghai" "ap-beijing" "ap-hongkong" "ap-singapore")


if [[ ! -f $JSON ]]; then
    echo "no json"
    exit 1

fi

    check_account=$(jq -r 'to_entries[] | "\(.key) \(.value.secretid) \(.value.secretkey)"' "$JSON") 
    
while read -r key secretid secretkey; do
    if [[ -z "$key" || -z "$secretid" || -z "$secretkey" ]]; then
        echo "value null"
        exit 1
    fi
        export TENCENTCLOUD_SECRET_ID="$secretid"
        export TENCENTCLOUD_SECRET_KEY="$secretkey"
        output_file="${key}.cdn.txt"
       # > $output_file


        echo "Checking Domain  account: $key"

        domain_list=$(tccli cdn DescribeDomains  --output json | jq -r '.Domains[] | "\(.Domain) \(.Origin.Origins[0]) \(.Status) \(.Area)"')

       
        if [[ -z "$domain_list" ]]; then
            echo "No domains found for account: $key"
            continue
        fi

       
        while read -r Domain Origin Status Area; do
            if [[ -z $Domain || -z "$Domain"  || -z "$Status" ]]; then
                echo "Skipping empty domain entry"
                continue
            fi
            echo -e "account: $key\t Domain: $Domain\t Origin: $Origin\t Status: $Status\t Area: $Area" >> "$output_file"

            
        done <<< "$domain_list"
    
done <<< "$check_account"


