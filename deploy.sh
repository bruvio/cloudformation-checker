#!/bin/bash


# Retrieve AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEMPLATE_DIR="/Users/brunoviola/WORK/cloudformation-checker"
AWS_REGION="eu-west-2"
export AWS_REGION


echo "AWS Account ID: $AWS_ACCOUNT_ID"



echo "Creating S3 bucket: $S3BucketName"
export S3BucketName="cloudformation-cheker-bruvio-${AWS_ACCOUNT_ID}"


echo "bucket names used for testing:"

VALID_BUCKET_NAME="this-is-a-valid-name-${AWS_ACCOUNT_ID}"
echo "valid bucket name: $VALID_BUCKET_NAME"


# Generate an invalid bucket name by including underscores
INVALID_BUCKET_NAME="invalid_bucket_name_with_underscores_${AWS_ACCOUNT_ID}"
echo "Invalid bucket name to trigger rollback: $INVALID_BUCKET_NAME"

echo ""

echo "Creating S3 bucket to store CF templates: $S3BucketName"
# Create the S3 bucket
# Attempt to create the S3 bucket
CREATE_BUCKET_OUTPUT=$(aws s3 mb s3://$S3BucketName --region eu-west-2 2>&1)
CREATE_BUCKET_EXIT_CODE=$?

if [ $CREATE_BUCKET_EXIT_CODE -ne 0 ]; then
  # Check if the error is due to the bucket already existing
  if echo "$CREATE_BUCKET_OUTPUT" | grep -q 'BucketAlreadyOwnedByYou'; then
    echo "Bucket already exists and is owned by you. Continuing..."
  elif echo "$CREATE_BUCKET_OUTPUT" | grep -q 'BucketAlreadyExists'; then
    echo "Bucket already exists but is owned by someone else. Please choose a different bucket name."

  else
    echo "Failed to create S3 bucket."
    echo "Error: $CREATE_BUCKET_OUTPUT"
    exit 1
  fi
fi

echo ""


echo "Upload templates to the bucket $S3BucketName"
aws s3 cp "$TEMPLATE_DIR/parent-stack.yml" s3://$S3BucketName/ --region $AWS_REGION
aws s3 cp "$TEMPLATE_DIR/nested-stack-1.yml" s3://$S3BucketName/ --region $AWS_REGION
aws s3 cp "$TEMPLATE_DIR/nested-stack-2.yml" s3://$S3BucketName/ --region $AWS_REGION
aws s3 cp "$TEMPLATE_DIR/nested-stack-3.yml" s3://$S3BucketName/ --region $AWS_REGION
aws s3 cp "$TEMPLATE_DIR/simple-s3-bucket.yml" s3://$S3BucketName/ --region $AWS_REGION

if [ $? -ne 0 ]; then
  echo "Failed to upload templates to S3 bucket."
  exit 1
fi
aws s3 ls s3://$S3BucketName




echo""

echo "Deploy the parent stack: ParentStack"

aws cloudformation create-stack \
  --stack-name ParentStack \
  --template-url https://$S3BucketName.s3.$AWS_REGION.amazonaws.com/parent-stack.yml \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=$S3BucketName \
    ParameterKey=NestedStack1BucketName,ParameterValue=my-nested-s3-bucket-1-${AWS_ACCOUNT_ID} \
    ParameterKey=NestedStack2TableName,ParameterValue=my-dynamodb-table-${AWS_ACCOUNT_ID} \
    ParameterKey=NestedStack3BucketName,ParameterValue=$INVALID_BUCKET_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION
if [ $? -ne 0 ]; then
  echo "Failed to initiate CloudFormation stack creation."
  exit 1
fi




echo ""
echo "provision valid s3 bucket - stackname MyS3BucketStack"
aws cloudformation create-stack \
    --stack-name MyS3BucketStack \
    --template-url https://$S3BucketName.s3.$AWS_REGION.amazonaws.com/simple-s3-bucket.yml \
    --parameters ParameterKey=S3BucketName,ParameterValue=$VALID_BUCKET_NAME \
    --region $AWS_REGION

if [ $? -ne 0 ]; then
  echo "Failed to initiate CloudFormation stack creation."
  exit 1
fi

echo ""
echo "provision invalid s3 bucket - stackname MyInvalidS3BucketStack"
aws cloudformation create-stack \
    --stack-name MyInvalidS3BucketStack \
    --template-url https://$S3BucketName.s3.$AWS_REGION.amazonaws.com/simple-s3-bucket.yml \
    --parameters ParameterKey=S3BucketName,ParameterValue=$INVALID_BUCKET_NAME \
    --region $AWS_REGION
if [ $? -ne 0 ]; then
  echo "Failed to initiate CloudFormation stack creation."
  exit 1
fi


echo "done"

return


echo "checking the nested stack"
python cf_status_checker.py ParentStack --region eu-west-2

echo "checking the good bucket stack"
python cf_status_checker.py MyS3BucketStack --region eu-west-2

echo "checking the invalid bucket stack"
python cf_status_checker.py MyInvalidS3BucketStack --region eu-west-2




echo "deleting stacks"

aws cloudformation delete-stack \
    --stack-name ParentStack 
aws cloudformation delete-stack \
    --stack-name MyS3BucketStack 
aws cloudformation delete-stack \
    --stack-name MyInvalidS3BucketStack 

