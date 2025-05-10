#!/bin/sh

# Clone the repository
git clone --branch minimalistic_v1 https://github.com/Nevelin-W/portfolio.git /app/portfolio

# Navigate to the project directory and install dependencies
cd /app/portfolio/myportfolio
flutter pub get > /dev/null 2>&1

# Build the Flutter project for web
flutter build web > /dev/null 2>&1

# Define S3 bucket and path
S3_BUCKET=${S3_BUCKET}

# Check if the bucket is empty
if aws s3 ls s3://${S3_BUCKET}/ > /dev/null 2>&1; then
  echo "Bucket is not empty, emptying bucket..."
  # Empty the bucket
  aws s3 rm s3://${S3_BUCKET}/ --recursive > /dev/null 2>&1
  echo "Bucket emptied successfully."
else
  echo "Bucket is already empty."
fi

# Upload the build directory to S3
echo "Uploading new build files to S3..."
aws s3 cp build/web s3://${S3_BUCKET}/ --recursive > /dev/null 2>&1 || { echo "AWS S3 upload failed"; exit 1; }
echo "Files uploaded successfully."

# Invalidate CloudFront Cache
echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION_ID} --paths "/*" > /dev/null 2>&1 || { echo "CloudFront invalidation failed"; exit 1; }
echo "CloudFront cache invalidated successfully."
