# --------------------------------------------------------------------------- 
# Filename: /home/ubuntu/wip/educative-apigateway-43-step/run.sh               #
# Path: /home/ubuntu/wip/educative-apigateway-43-step                          #
# Created Date: Sunday, September 11th 2022, 4:42:55 am                        #
# Author: Vikas K Solegaonkar                                                  #
#                                                                              #
# Copyright (c) 2022 Vikas K Solegaonkar                                       #
# --------------------------------------------------------------------------- 



# -----------------------------------------------------------------
# Configure the AWS CLI to let it communicate with your account
# -----------------------------------------------------------------
aws configure set aws_access_key_id $ACCESS_KEY_ID
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY
aws configure set region us-east-1

# -----------------------------------------------------------------
# Delete any old deployments
# -----------------------------------------------------------------
# 1. Trigger CloudFormation stack delete
# 2. Wait for the stack to be deleted 
aws cloudformation delete-stack --stack-name  EducativeCourseApiGateway
aws cloudformation wait stack-delete-complete --stack-name EducativeCourseApiGateway


# -----------------------------------------------------------------
# Deploying a Lambda Function requires two steps.
# -----------------------------------------------------------------
# 1. Create a deployment ZIP file and upload it to S3
# 2. Deploy the CloudFormation template that picks this ZIP file and makes a Lambda function
#
# The below code will do both

# -----------------------------------------------------------------
# Cleanup anything that is left over from the last deployment.
# -----------------------------------------------------------------
rm -f *.zip 

# -----------------------------------------------------------------
# Create a unique S3 Bucket. The name of S3 bucket is derived from the access key. So it has to be unique
# -----------------------------------------------------------------
bucket=`echo $ACCESS_KEY_ID | tr '[:upper:]' '[:lower:]'`
aws s3 mb s3://educative.${bucket} --region us-east-1
#aws s3 mb s3://educative.${bucket}.archive --region us-east-1

# -----------------------------------------------------------------
# It is important that this zip file has a new name everytime we deploy. Else, the new code is not picked.
# We start by creating a random string. This is an important part of CloudFormation deployments.
# -----------------------------------------------------------------
RAND=$(dd if=/dev/random bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')

# -----------------------------------------------------------------
# Build the zip file that we want to deploy. At this point, we include the index.js in our 
# -----------------------------------------------------------------
zip -r EducativeEcho.${RAND}.zip index.js

# -----------------------------------------------------------------
# Upload the lambda zip file to the S3 bucket. 
# -----------------------------------------------------------------
aws s3 cp EducativeEcho.${RAND}.zip s3://educative.${bucket}

# -----------------------------------------------------------------
# With everything ready, we initiate the CloudFormation deployment.
# -----------------------------------------------------------------
ARTIFACT_BUCKET=educative.${bucket}
ARCHIVE_BUCKET=educative.${bucket}.archive

aws s3 cp ApiGatewayOpenApiSpec.yaml s3://$ARTIFACT_BUCKET
aws s3 cp StepFunction.json s3://$ARTIFACT_BUCKET

aws cloudformation package --template-file template.yml --s3-bucket $ARTIFACT_BUCKET --output-template-file out.yml
aws cloudformation deploy --template-file out.yml --stack-name EducativeCourseApiGateway --parameter-overrides SourceCodeBucket=$ARTIFACT_BUCKET ArchiveS3BucketName=$ARCHIVE_BUCKET DeployId="$RAND" --capabilities CAPABILITY_NAMED_IAM --region us-east-1
rm out.yml

# -----------------------------------------------------------------
# Initialize the invocation counter in the DynamoDB table
# -----------------------------------------------------------------
aws dynamodb put-item --table-name EducativeAPIAnalytics --item '{"apiName": {"S": "EchoAPI"}, "invocationCount": {"N": "0"}}' --region us-east-1

# -----------------------------------------------------------------
# Get the API ID of the Rest API we just created.
# -----------------------------------------------------------------
apiId=`aws cloudformation list-stack-resources --stack-name EducativeCourseApiGateway | jq -r ".StackResourceSummaries[0].PhysicalResourceId"`
echo "API ID: $apiId"

# -----------------------------------------------------------------
# This is the URL for the API we just created
# -----------------------------------------------------------------
url="https://${apiId}.execute-api.us-east-1.amazonaws.com/v1"
echo $url

# -----------------------------------------------------------------
# Invoke the URL to test the response
# -----------------------------------------------------------------
curl --location --request POST $url --header 'Content-Type: application/json' --data-raw '{ "message": "Hello World" }' 

