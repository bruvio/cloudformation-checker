# CloudFormation Checker

## Overview

This repository contains scripts and templates to deploy AWS CloudFormation stacks, including a parent stack with nested stacks. It demonstrates both successful and failed stack deployments to help you understand how to detect and troubleshoot issues in CloudFormation stacks.

The key components are:

- **Bash Deployment Script (`deploy.sh`)**: Automates the deployment of CloudFormation stacks, uploads templates to S3, and intentionally triggers stack failures for testing.
- **CloudFormation Templates**: YAML templates defining AWS resources, including nested stacks and S3 buckets.
- **Python Status Checker (`cf_status_checker.py`)**: Analyzes CloudFormation stacks to find the root cause of failures or rollbacks.

## Assumptions and Prerequisites

Before running the scripts in this repository, ensure you have the following:

- **AWS Account**: Access to an AWS account with permissions to create and manage CloudFormation stacks, S3 buckets, DynamoDB tables, and IAM roles.
- **AWS CLI Installed**: AWS Command Line Interface (CLI) installed on your machine. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **AWS CLI Configured**: AWS CLI configured with your AWS credentials. Run `aws configure` to set up.
- **Python 3 Installed**: Python 3.x installed on your machine.
- **Boto3 Library**: Install the `boto3` library using `pip install boto3`.
- **Permissions**: AWS credentials with sufficient permissions to perform CloudFormation operations, S3 actions, and STS calls.

## Repository Contents

- **`deploy.sh`**: Bash script to deploy the CloudFormation stacks and test scenarios.
- **CloudFormation Templates**:
  - `parent-stack.yml`
  - `nested-stack-1.yml`
  - `nested-stack-2.yml`
  - `nested-stack-3.yml`
  - `simple-s3-bucket.yml`
- **`cf_status_checker.py`**: Python script to check the status of CloudFormation stacks and identify failure causes.

## How to Deploy the Infrastructure

### 1. Clone the Repository

```bash
git clone https://github.com/bruvio/cloudformation-checker.git
cd cloudformation-checker
```
### 2. Configure AWS CLI and Credentials

Ensure your AWS CLI is configured:

```bash

aws configure
```

### 3. Install Required Python Libraries

```bash

pip install boto3
```
### 4. Modify the Script (If Necessary)

Update the TEMPLATE_DIR variable in deploy_stack.sh to the path where your templates are located:

```bash

TEMPLATE_DIR="/path/to/cloudformation-checker/cloudformation"
```

### 5. Run the Deployment Script

```bash

source deploy.sh
```

This script will:

    Retrieve your AWS Account ID.
    Set necessary environment variables.
    Create an S3 bucket to store CloudFormation templates.
    Upload templates to the S3 bucket.
    Deploy a parent stack (ParentStack) with nested stacks, intentionally causing a failure in one nested stack.
    Deploy a valid S3 bucket stack (MyS3BucketStack).
    Deploy an invalid S3 bucket stack (MyInvalidS3BucketStack) to trigger a failure.

### 6. Check Stack Statuses (Optional)

Use the Python script to check the status of the stacks:

```bash

python cf_status_checker.py ParentStack --region eu-west-2
python cf_status_checker.py MyS3BucketStack --region eu-west-2
python cf_status_checker.py MyInvalidS3BucketStack --region eu-west-2
```
### 7. Clean Up Resources

After testing, delete the stacks to avoid unnecessary charges:

```bash

aws cloudformation delete-stack --stack-name ParentStack --region eu-west-2
aws cloudformation delete-stack --stack-name MyS3BucketStack --region eu-west-2
aws cloudformation delete-stack --stack-name MyInvalidS3BucketStack --region eu-west-2
```

## Additional Notes

    Error Handling: The script includes error handling for bucket creation and stack deployment.
    Modular Templates: The CloudFormation templates are modular and can be reused or modified for other purposes.
    Learning Tool: This repository serves as a practical example for learning about CloudFormation stack deployments and troubleshooting, and is not in a production-ready state, use at your own risk.

## License

This project is open-source and available under the MIT License.

## Contact

For questions or support, please open an issue on the repository or contact bruvio.