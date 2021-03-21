#!/bin/bash
set -e

WORKFLOW=$1
# Spin up localstack, postgres, and redis
docker-compose up -d localstack
docker-compose up -d postgres && sleep 5
docker-compose up -d redis

# Create S3 buckets
aws --endpoint-url=http://localhost:4572 s3 mb s3://local-storage-pennsieve
aws --endpoint-url=http://localhost:4572 s3 mb s3://local-uploads-pennsieve
aws --endpoint-url=http://localhost:4572 s3 mb s3://local-timeseries

# Seed S3
aws s3 sync s3://pennsieve-ops-use1/testing-resources/etl/data/$WORKFLOW/ /tmp/${NETWORK_NAME}/$WORKFLOW
aws --endpoint-url=http://localhost:4572 s3 sync /tmp/${NETWORK_NAME}/$WORKFLOW s3://local-storage-pennsieve/$WORKFLOW/data/
aws --endpoint-url=http://localhost:4572 s3 sync /tmp/${NETWORK_NAME}/$WORKFLOW s3://local-timeseries/$WORKFLOW/data/

# Set SSM params
function add_ssm_val(){
    KEY=$1; VALUE=$2;
    aws --region=us-east-1 \
        --endpoint=http://localhost:4583 \
        ssm put-parameter \
        --name "$KEY" \
        --value "$VALUE" \
        --type "String"
}

# tabular
add_ssm_val "local-bf-postgres-db"        "postgres"
add_ssm_val "local-bf-postgres-host"      "postgres"
add_ssm_val "local-bf-postgres-password"  "password"
add_ssm_val "local-bf-postgres-port"      "5432"
add_ssm_val "local-bf-postgres-user"      "postgres"

# timeseries
add_ssm_val "local-postgres-db"           "postgres"
add_ssm_val "local-postgres-host"         "postgres"
add_ssm_val "local-postgres-password"     "password"
add_ssm_val "local-postgres-port"         "5432"
add_ssm_val "local-postgres-user"         "postgres"
add_ssm_val "local-timeseries-s3-bucket"  "local-timeseries"

# basics
add_ssm_val "local-etl-storage-bucket"    "local-storage-pennsieve"
add_ssm_val "local-etl-upload-bucket"     "local-upload-pennsieve"
add_ssm_val "local-redis-host"            "redis"

if [ -e tests/$WORKFLOW/local-seed.sql ]
then
    CONTAINER=$(docker-compose ps postgres | tail -n 1 | awk '{print $1}')
    while true; do
        echo "Waiting for $CONTAINER to be healthy..."
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER)
        if [ "$HEALTH" == healthy ]; then
            break
        elif [ "$HEALTH" == unhealthy ]; then
            echo "$CONTAINER is unhealthy"
            exit 1
        fi
        sleep 5
    done
    docker-compose exec -T postgres sh -c "psql -v ON_ERROR_STOP=1 postgres < /tests/$WORKFLOW/local-seed.sql"
else
    exit 0
fi
