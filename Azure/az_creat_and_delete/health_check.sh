#!/bin/bash


while read DOMAIN;do
RE=$(curl -s https://$DOMAIN/health-check)


  if echo "$RE" | grep -q "OK"; then
    echo "domain: $DOMAIN status: $RE"
  else
    echo "domain: $DOMAIN response: Failed"
  fi

done < health_check.txt