#!/bin/bash

HOSTED_ZONE_NAME="aws.cts.care."
TTL=300

#  ********************************* fetch IMDSv2 token
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

if [[ -z "$IMDS_TOKEN" ]]; then
  echo "Failed to fetch IMDSv2 token."
  exit 1
fi

# ********************************* instance ID
ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# ********************************* public IP
IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

if [[ -z "$IP" ]]; then
  echo "No public IP found for instance $ID"
  exit 1
fi

# ********************************* hosted zone ID 
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '$HOSTED_ZONE_NAME'].Id" --output text | sed 's|/hostedzone/||')

if [[ -z "$HOSTED_ZONE_ID" ]]; then
  echo "Could not find Hosted Zone ID for $HOSTED_ZONE_NAME"
  exit 1
fi

# ********************************* instance name from EC2 tag
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)

if [[ -z "$INSTANCE_NAME" ]]; then
  echo "Could not retrieve Name tag from EC2"
  exit 1
fi

RECORD_NAME="${INSTANCE_NAME}.${HOSTED_ZONE_NAME}"
echo "Using DNS record: $RECORD_NAME"

#  ********************************* route53 JSON
cat > /tmp/change-batch.json << EOF
{
  "Comment": "Auto-updated A record from EC2 instance",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME",
        "Type": "A",
        "TTL": $TTL,
        "ResourceRecords": [
          {
            "Value": "$IP"
          }
        ]
      }
    }
  ]
}
EOF

# ********************************* update route53
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch file:///tmp/change-batch.json

if [[ $? -eq 0 ]]; then
  echo "Successfully updated DNS record: $RECORD_NAME -> $IP"
else
  echo "Failed to update DNS record."
fi
