#!/bin/bash

source .env

if [[ -z "${TENANCY_ID}" ]]; then
    echo "TENANCY_ID is unset or empty. Please change in .env file"
    exit 1
else
    echo "TENANCY_ID is set correctly"
fi

# To verify that the authentication with Oracle cloud works
echo "Checking Connection with this request: "
oci iam compartment list
if [ $? -ne 0 ]; then
    echo "Connection to Oracle cloud is not working. Check your setup and config again!"
    exit 1
fi

# ----------------------CUSTOMIZE---------------------------------------------------------------------------------------

# Don't go too low or you run into 429 TooManyRequests
requestInterval=60 # seconds

# VM params
cpus=4 # max 4 cores
ram=24 # max 24gb memory
bootVolume=50 # disk size in gb

# ----------------------ENDLESS LOOP TO REQUEST AN ARM INSTANCE---------------------------------------------------------

IFS=',' read -ra AD_ARRAY <<< "$AVAILABILITY_DOMAIN"

while true; do
    for AD in "${AD_ARRAY[@]}"; do
        echo "Launching instance in AD: $AD"

        oci compute instance launch --no-retry \
        --auth api_key \
        --profile "$PROFILE" \
        --display-name "$DISPLAY_NAME" \
        --compartment-id "$TENANCY_ID" \
        --image-id "$IMAGE_ID" \
        --subnet-id "$SUBNET_ID" \
        --availability-domain "$AD" \
        --shape 'VM.Standard.A1.Flex' \
        --shape-config "{\"ocpus\":$cpus,\"memoryInGBs\":$ram}" \
        --boot-volume-size-in-gbs "$bootVolume" \
        --ssh-authorized-keys-file "$PATH_TO_PUBLIC_SSH_KEY"

        # Check if the command was successful
        if [ $? -eq 0 ]; then
            echo "Instance created successfully! Exiting."
            break
        else
            echo "Instance creation failed. Retrying in $requestInterval seconds..."
        fi

        sleep "$requestInterval"
    done
done
