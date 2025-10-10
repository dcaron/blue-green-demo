#!/bin/bash
# Script to build and load the maven-advisor Docker image into Concourse
set -e

echo "Building maven-advisor Docker image..."
cd "$(dirname "$0")"
docker build -t maven-advisor:latest -f Dockerfile.advisor .

echo "Exporting image to tar file..."
docker save maven-advisor:latest -o /tmp/maven-advisor.tar

echo "Finding Concourse container..."
CONCOURSE_CONTAINER=$(docker ps --format '{{.Names}}' | grep 'blue-green-demo-concourse' | grep -v 'db' | head -1)

if [ -z "$CONCOURSE_CONTAINER" ]; then
    echo "ERROR: Could not find Concourse container"
    exit 1
fi

echo "Using Concourse container: $CONCOURSE_CONTAINER"

echo "Copying image to Concourse container..."
docker cp /tmp/maven-advisor.tar "$CONCOURSE_CONTAINER:/tmp/"

echo "Importing image into Concourse containerd..."
docker exec "$CONCOURSE_CONTAINER" /usr/local/concourse/bin/ctr -n concourse images import /tmp/maven-advisor.tar

echo "Cleaning up..."
rm /tmp/maven-advisor.tar
docker exec "$CONCOURSE_CONTAINER" rm /tmp/maven-advisor.tar

echo "✓ Successfully loaded maven-advisor:latest into Concourse"
echo "You can now run the SAA pipeline"
