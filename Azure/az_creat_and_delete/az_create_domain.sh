#!/bin/bash

AZJSON="az.json"
#GROUP="ops-proxy"
GROUP="devops"
DOMAIN_LIST="az_domains.txt"
#custom_domain_name=$(echo "$DOMAIN_LIST" | sed 's/\./-/g')



if [[ ! -f $AZJSON ]];then
    echo "az.json File missing"
    exit 1
fi

check_account=$(jq -r 'to_entries[] | "\(.KEY) \(.value.CLIENT_ID) \(.value.CLIENT_SECRET) \(.value.TENANT_ID) \(.value.SUBSCRIPTION_ID)"' "$AZJSON")
exec 3< <(echo "$check_account")
while read -r KEY ID SECRET TENANT SUBSCRIPTION <&3; do
    
    if [[ -z "$KEY" || -z "$ID" || -z "$SECRET" || -z "$TENANT" || -z "$SUBSCRIPTION" ]]; then
        echo "json error"
        exit 1
    else
        echo "Executing Azure login with service principal"
        login=$(az login --service-principal -u "$ID" -p "$SECRET" --tenant "$TENANT" | jq -r '.[].cloudName') 
        echo "Cloud Name: $login"

        if [[ $? -ne 0 ]]; then
            echo "Login failed for $KEY"
            exit 1
        fi
    fi
done
profile_data=($(jq -r '.AZ.FRONTDOORS[] | [ 
    "\(.profile_name1),\(.endpoint1),\(.route_endpoint1),\(.route_name1)", 
    "\(.profile_name2),\(.endpoint2),\(.route_endpoint2),\(.route_name2)", 
    "\(.profile_name3),\(.endpoint3),\(.route_endpoint3),\(.route_name3)", 
    "\(.profile_name4),\(.endpoint4),\(.route_endpoint4),\(.route_name4)",
    "\(.profile_name5),\(.endpoint5),\(.route_endpoint5),\(.route_name5)"    
    ] | map(select(. != null and . != "," and . != "null,null,null,null")) | .[]' "$AZJSON"))


echo "chosen FrontDoor"

select chosen_pair in "${profile_data[@]}"; do
    if [[ -n $chosen_pair ]]; then
        IFS=',' read -r chosen_profile chosen_endpoint chosen_route_endpoint chosen_route_name <<< "$chosen_pair"
        
        echo "profile_name：$chosen_profile"
        echo "endpoint：$chosen_endpoint"
        echo "route_endpoint：$chosen_route_endpoint"
        echo "route_name：$chosen_route_name"
        break
    else
        echo "error"
    fi
done


exec 3<&-

output="validationToken.txt"
> "$output"

temp_file="route_id.txt"
> "$temp_file" 

while IFS= read -r domain; do
    
    custom_domain_name=$(echo "$domain" | sed 's/\./-/g')
    
        existing_domain=$(az afd custom-domain show --profile-name "$chosen_profile" \
                                                 --resource-group "$GROUP" \
                                                 --custom-domain-name "$custom_domain_name" \
                                                 --query "id" -o tsv 2>/dev/null)

    if [[ -n "$existing_domain" ]]; then
        echo "Custom domain $custom_domain_name already exists, skipping creation."
        continue  
    fi

    azdomain=$(az afd custom-domain create --custom-domain-name "$custom_domain_name" \
                                           --profile-name "$chosen_profile" \
                                           --resource-group "$GROUP" \
                                           --host-name "$domain" \
                                           --certificate-type "ManagedCertificate" \
                                           --minimum-tls-version "TLS12" \
                                           --output json | jq -r '.validationProperties.validationToken')    
    if [[ -n "$azdomain" ]]; then
        domain_id=$(az afd custom-domain show --profile-name "$chosen_profile" \
                                              --resource-group "$GROUP" \
                                              --custom-domain-name "$custom_domain_name" \
                                              --query "id" -o tsv)

        route_update_id="{\"id\": \"$domain_id\"}"
        #route_update_id=$(echo "$route_update_id" | tr -d '\r' | sed 's/[[:space:]]*$//')
           echo "$route_update_id"  >> "$temp_file"        


        echo "域名 $domain" >> "$output"
        echo "主機紀錄:_dnsauth" >> "$output"
        echo "TXT紀錄值：$azdomain" >> "$output"
        echo "主機紀錄: @ " >> "$output"
        echo "Cname : $chosen_endpoint" >> "$output" 
        echo "-------------------------------" >> "$output"
    else
        echo "failed to create custom domain for $domain"
        exit 1
    fi
done < "$DOMAIN_LIST"

#custom_domains_str=$(cat "$temp_file" | tr '\n' ',')
#custom_domains_str=${custom_domains_str%,}


while IFS= read -r line; do
az afd route update --profile-name "$chosen_profile" \
                   --resource-group "$GROUP" \
                   --route-name "$chosen_route_name" \
                   --endpoint-name "$chosen_route_endpoint"  \
                    --add customDomains "$line" > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then 
        echo "Failed to update route with domain: $line"
    fi

   

done < "$temp_file"                    
echo "All done"

rm "$temp_file"
