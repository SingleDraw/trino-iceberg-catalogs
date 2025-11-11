#!/bin/bash

# read .env.images file and create associative array of image names
sed -i 's/\r$//' .env.images  # remove possible Windows line endings
declare -A IMAGES
while IFS='=' read -r key value; do
    # skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    IMAGES["$key"]="$value"
done < .env.images

echo "Pulling required Docker images..."

function pull_image() {
    IMAGE_NAME=$1

    # declare -p IMAGES # for debugging

    if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        echo "Docker image $IMAGE_NAME found locally."
    else
        echo "Pulling Docker image $IMAGE_NAME..."
        docker pull "$IMAGE_NAME"
    fi
}

# Pull each image defined in the IMAGES array
for IMAGE_KEY in "${!IMAGES[@]}"; do
    pull_image "${IMAGES[$IMAGE_KEY]}"
done

if [ $? -ne 0 ]; then
    echo "Error occurred while pulling Docker images."
    exit 1
fi
echo "All required Docker images are pulled."