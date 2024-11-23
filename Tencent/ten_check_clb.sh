#!/bin/bash

JSON="output.json"
#REGIONS=("ap-guangzhou" "ap-shanghai" "ap-beijing" "ap-hongkong" "ap-singapore")


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
    output_file="${key}.clb.txt"
    #> $output_file

    echo "account check $key"


        clb_list=$(tccli clb DescribeLoadBalancers --output json | jq -r '.LoadBalancerSet[] | "\(.LoadBalancerId) \(.LoadBalancerName) \(.LoadBalancerType) \(.TargetRegionInfo.Region)"')
    while read -r LoadBalancerId LoadBalancerName LoadBalancerType Region; do
        if [[ -z "$LoadBalancerId" || -z "$LoadBalancerName" || -z "$LoadBalancerType" || -z "$Region" ]]; then
            echo "Skipping empty load balancer entry"
            continue
        fi
        echo -e "account: $key\t LoadBalancerId: $LoadBalancerId\t LoadBalancerName: $LoadBalancerName\t LoadBalancerType: $LoadBalancerType\t Region: $Region" >> "$output_file"
    done <<< "$clb_list"
done