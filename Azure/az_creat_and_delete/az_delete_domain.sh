#!/bin/bash

AZJSON="az.json"
#GROUP="ops-proxy"
GROUP="devops"
DOMAIN_LIST="az_domains.txt"

function check_azjson_file() {
    if [[ ! -f $AZJSON ]]; then
        echo "az.json File missing"
        exit 1
    fi
}

function parse_account_info() {
    jq -r '"AZ \(.AZ.CLIENT_ID) \(.AZ.CLIENT_SECRET) \(.AZ.TENANT_ID) \(.AZ.SUBSCRIPTION_ID)"' "$AZJSON"
}

function azure_login() {
    local key=$1 id=$2 secret=$3 tenant=$4

    echo "Executing Azure login with service principal"
    login=$(az login --service-principal -u "$id" -p "$secret" --tenant "$tenant" | jq -r '.[].cloudName')

    if [[ $? -ne 0 ]]; then
        echo "Login failed for $key"
        exit 1
    else
        echo "Cloud Name: $login"
    fi
}

function select_frontdoor_profile() {
    profile_data=($(jq -r '.AZ.FRONTDOORS[] | [ 
        "\(.profile_name1),\(.endpoint1),\(.route_endpoint1),\(.route_name1)", 
        "\(.profile_name2),\(.endpoint2),\(.route_endpoint2),\(.route_name2)", 
        "\(.profile_name3),\(.endpoint3),\(.route_endpoint3),\(.route_name3)", 
        "\(.profile_name4),\(.endpoint4),\(.route_endpoint4),\(.route_name4)", 
        "\(.profile_name5),\(.endpoint5),\(.route_endpoint5),\(.route_name5)"    
    ] | map(select(. != null and . != "," and . != "null,null,null,null")) | .[]' "$AZJSON"))

    echo "Choose FrontDoor profile:"
    select chosen_pair in "${profile_data[@]}"; do
        if [[ -n $chosen_pair ]]; then
            IFS=',' read -r chosen_profile chosen_endpoint chosen_route_endpoint chosen_route_name <<< "$chosen_pair"
            echo "Selected profile_name：$chosen_profile"
            echo "endpoint：$chosen_endpoint"
            echo "route_endpoint：$chosen_route_endpoint"
            echo "route_name：$chosen_route_name"
            break
        else
            echo "Invalid selection, please try again."
        fi
    done
}

function get_custom_domains() {
    az afd custom-domain list --profile-name "$chosen_profile" \
                              --resource-group "$GROUP" \
                              --query "[].id" -o tsv
}

function delete_custom_domain() {
    local domain_name=$1
    az afd custom-domain delete --profile-name "$chosen_profile" \
                                 --resource-group "$GROUP" \
                                 --custom-domain-name "$domain_name" \
                                 --yes --no-wait 2>> error.log
}

#function remove_route_domain() {
#    local index=$1
#    az afd route update --profile-name "$chosen_profile" \
#                        --resource-group "$GROUP" \
#                        --route-name "$chosen_route_name" \
#                        --endpoint-name "$chosen_route_endpoint" \
#                        --remove customDomains "$index" > /dev/null 2>&1
#}

function main() {
    check_azjson_file

    account_info=$(parse_account_info)
    echo "$account_info" | while read -r KEY ID SECRET TENANT SUBSCRIPTION; do
        azure_login "$KEY" "$ID" "$SECRET" "$TENANT"
    done

    select_frontdoor_profile

    custom_domains=$(get_custom_domains)
    IFS=$'\n' read -r -d '' -a domain_array <<< "$custom_domains"

    echo "custom domains id:"
    for i in "${!domain_array[@]}"; do
        domain_name=$(echo "${domain_array[$i]}" | sed 's/.*\///')
        echo "$i) $domain_name"
    done

    declare -A domains_to_remove

    while IFS= read -r domain; do
        custom_domain_name=$(echo "$domain" | sed 's/\./-/g')

        index_to_remove=-1
        for i in "${!domain_array[@]}"; do
            domain_name=$(echo "${domain_array[$i]}" | sed 's/.*\///')
            if [[ "$domain_name" == "$custom_domain_name" ]]; then
                index_to_remove=$i
                domains_to_remove["$custom_domain_name"]=$index_to_remove
                break
            fi
        done

        if [[ $index_to_remove -eq -1 ]]; then
            echo "Domain $custom_domain_name does not exist in the provided custom domain list"
            domains_to_remove["$custom_domain_name"]=-1
        else
            echo "Skip: $custom_domain_name"
        fi
    done < "$DOMAIN_LIST"

    #for domain_name in "${!domains_to_remove[@]}"; do
    #    index_to_remove="${domains_to_remove[$domain_name]}"
    #    if [[ $index_to_remove -ne -1 ]]; then
    #        echo "Removing custom domain with index $index_to_remove from route"
    #        remove_route_domain "$index_to_remove"
    #    fi
    #done

    #wait
    > error.log
    for domain_name in "${!domains_to_remove[@]}"; do
        echo "Deleting custom domain: $domain_name"
        delete_custom_domain "$domain_name"
    done

    if [[ $? -ne 0 ]]; then
        echo "Failed to delete custom domain: $domain_name retry delete "
    else
        echo "Successfully deleted custom domain: $domain_name"
    fi
}

main
