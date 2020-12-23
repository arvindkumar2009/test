#!/bin/bash
START=$(date "+%m/%d/%Y")
END=$(date -v-60M "+%m/%d/%Y")
FILE="$(date +"%Y_%m_%d_%I_%p").json"
for i in `cat userlist.txt`
do 
  echo $i
  aws cloudtrail lookup-events --start-time $START --end-time $END --lookup-attributes AttributeKey=Username,AttributeValue=$i > "$i-$FILE"
  cat "$i-$FILE"|jq -r '.Events[] | select(.EventName| select(startswith("Create")))' >> "output-$FILE"
  aws s3 cp "output-$FILE" s3://arv-2009/"output-$FILE"
  mail -a "output-$FILE" -s "Coudtrail Report" user@example.com < /dev/null
done
