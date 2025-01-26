#!/bin/bash

# Set variables
KEY_NAME="bcitkey"
PUBLIC_KEY_FILE="bcitkey.pub"

# Check if the public key file exists
if [[ ! -f $PUBLIC_KEY_FILE ]]; then
  echo "Error: Public key file '$PUBLIC_KEY_FILE' not found."
  exit 1
fi

# Import the public key to AWS
aws ec2 import-key-pair \
  --key-name "$KEY_NAME" \
  --public-key-material fileb://"$PUBLIC_KEY_FILE"

if [[ $? -eq 0 ]]; then
  echo "Public key '$KEY_NAME' successfully imported to AWS."
else
  echo "Failed to import public key to AWS."
  exit 1
fi
