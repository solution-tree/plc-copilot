#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Install Docker
# ------------------------------------------------------------------------------
dnf update -y
dnf install -y docker amazon-cloudwatch-agent aws-cli jq
systemctl enable docker
systemctl start docker

# ------------------------------------------------------------------------------
# Install CloudWatch Agent
# ------------------------------------------------------------------------------
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/qdrant/qdrant.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 30
          }
        ]
      }
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ------------------------------------------------------------------------------
# Prepare Qdrant directories
# ------------------------------------------------------------------------------
mkdir -p /data/qdrant/storage
mkdir -p /data/qdrant/snapshots
mkdir -p /var/log/qdrant

# ------------------------------------------------------------------------------
# Retrieve Qdrant API key from Secrets Manager
# ------------------------------------------------------------------------------
QDRANT_API_KEY=$(aws secretsmanager get-secret-value \
  --secret-id "${secret_id}" \
  --region "${region}" \
  --query 'SecretString' --output text 2>/dev/null | jq -r '.qdrant_api_key // empty' || echo "")

# ------------------------------------------------------------------------------
# Run Qdrant container
# ------------------------------------------------------------------------------
QDRANT_DOCKER_ARGS="-d --name qdrant --restart always \
  -p 6333:6333 -p 6334:6334 \
  -v /data/qdrant/storage:/qdrant/storage \
  -v /data/qdrant/snapshots:/qdrant/snapshots"

if [ -n "$QDRANT_API_KEY" ]; then
  QDRANT_DOCKER_ARGS="$QDRANT_DOCKER_ARGS -e QDRANT__SERVICE__API_KEY=$QDRANT_API_KEY"
fi

docker run $QDRANT_DOCKER_ARGS qdrant/qdrant:latest \
  2>&1 | tee /var/log/qdrant/qdrant.log &

# Wait for Qdrant to be ready
for i in $(seq 1 30); do
  if curl -sf http://localhost:6333/healthz > /dev/null 2>&1; then
    echo "Qdrant is healthy"
    break
  fi
  sleep 2
done

# ------------------------------------------------------------------------------
# Setup daily snapshot cron (2 AM UTC)
# ------------------------------------------------------------------------------
cat > /usr/local/bin/qdrant-snapshot.sh <<'SNAPSHOT'
#!/bin/bash
set -euo pipefail

REGION="${region}"
S3_BUCKET="${s3_bucket}"
TIMESTAMP=$(date -u +%%Y%%m%%d-%%H%%M%%S)

# Get all collections
COLLECTIONS=$(curl -sf http://localhost:6333/collections | jq -r '.result.collections[].name')

for COLLECTION in $COLLECTIONS; do
  # Create snapshot
  SNAPSHOT_NAME=$(curl -sf -X POST "http://localhost:6333/collections/$COLLECTION/snapshots" | jq -r '.result.name')

  # Upload to S3
  aws s3 cp "/data/qdrant/snapshots/$COLLECTION/$SNAPSHOT_NAME" \
    "s3://$S3_BUCKET/qdrant-snapshots/$COLLECTION/$TIMESTAMP-$SNAPSHOT_NAME" \
    --region "$REGION"

  # Clean up local snapshot
  curl -sf -X DELETE "http://localhost:6333/collections/$COLLECTION/snapshots/$SNAPSHOT_NAME"
done
SNAPSHOT

chmod +x /usr/local/bin/qdrant-snapshot.sh

# Add cron job (2 AM UTC daily)
echo "0 2 * * * /usr/local/bin/qdrant-snapshot.sh >> /var/log/qdrant/snapshot.log 2>&1" | crontab -
