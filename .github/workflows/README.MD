# Portfolio Website Resource Provisioning

This repository contains workflows for provisioning resources necessary for hosting a portfolio website using AWS services and Docker. The workflows automate the setup and teardown of infrastructure, including S3 buckets, CloudFront distributions, and SSL/TLS certificates.

## Workflows

This repository includes the following GitHub Actions workflows:

1. **build-flutter-image.yml**  
   - Builds a custom Docker image for the building flutter app and uploading build to aws S3
   
2. **s3-bucket-setup.yml**  
   - Sets up an S3 bucket and a CloudFront distribution. This workflow uses the custom Docker image to build the latest version of the website from the webpage repository and uploads the web files to the S3 bucket.
   - It includes functionality to run Terraform to either create the necessary AWS infrastructure if it does not exist or provision it if it does. If the infrastructure already exists it gets verified and only the Docker image will be run.

3. **s3-bucket-teardown.yml**  
   - Teardown workflow that removes the S3 bucket and associated CloudFront distribution, effectively reversing the actions of `s3-bucket-setup.yml`.

4. **ssl-tls-certificate-create.yml**  
   - Provisions an SSL/TLS certificate in AWS to secure the website.

5. **ssl-tls-certificate-destroy.yml**  
   - Teardown workflow that removes the SSL/TLS certificate, reversing the actions of `ssl-tls-certificate-create.yml`.
