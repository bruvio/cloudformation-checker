import os
import sys
import boto3
import json
import argparse
from botocore.exceptions import ClientError


def get_stack_status(stack_id):
    client = boto3.client("cloudformation", region_name=os.getenv("AWS_REGION"))
    try:
        response = client.describe_stacks(StackName=stack_id)
        stack_status = response["Stacks"][0]["StackStatus"]
        return stack_status
    except ClientError as e:
        print(f"Error fetching stack status for {stack_id}: {e}")
        sys.exit(1)


def get_failed_resource(stack_id, path=None, visited_stacks=None):
    if path is None:
        path = []
    if visited_stacks is None:
        visited_stacks = set()

    if stack_id in visited_stacks:
        # Avoid infinite recursion
        return None
    visited_stacks.add(stack_id)

    client = boto3.client("cloudformation", region_name=os.getenv("AWS_REGION"))
    try:
        # Collect all stack events
        events = []
        paginator = client.get_paginator("describe_stack_events")
        page_iterator = paginator.paginate(StackName=stack_id)

        for page in page_iterator:
            events.extend(page["StackEvents"])

        # Sort events in chronological order (oldest first)
        events.sort(key=lambda x: x["Timestamp"])

        for event in events:
            if event["ResourceStatus"] in [
                "CREATE_FAILED",
                "UPDATE_FAILED",
                "DELETE_FAILED",
                "ROLLBACK_IN_PROGRESS",
                "ROLLBACK_FAILED",
            ]:
                resource = {
                    "StackId": event["StackId"],
                    "ResourceName": event["LogicalResourceId"],
                    "ResourceType": event["ResourceType"],
                    "Timestamp": event["Timestamp"].isoformat(),
                    "Status": event["ResourceStatus"],
                    "StatusReason": event.get("ResourceStatusReason", "No reason provided"),
                    "Path": path + [event["LogicalResourceId"]],
                }
                if resource["ResourceType"] == "AWS::CloudFormation::Stack":
                    # Recursively get failed resource from nested stack if PhysicalResourceId is available
                    nested_stack_id = event.get("PhysicalResourceId")
                    if nested_stack_id:
                        nested_resource = get_failed_resource(nested_stack_id, resource["Path"], visited_stacks)
                        if nested_resource:
                            return nested_resource
                        else:
                            # If no failed resource found in nested stack, return current resource
                            return resource
                    else:
                        # PhysicalResourceId is empty, cannot recurse further
                        # Return the current resource with the failure reason
                        return resource
                else:
                    # Found the first failed resource
                    return resource
        return None
    except ClientError as e:
        print(f"Error fetching stack events for {stack_id}: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Retrieve the status of a CloudFormation stack and identify any failed resources."
    )
    parser.add_argument("stack_name", help="The name or ID of the CloudFormation stack")
    parser.add_argument("--region", help="AWS region where the stack is located")
    args = parser.parse_args()

    # Set AWS region
    if args.region:
        os.environ["AWS_REGION"] = args.region
    elif not os.getenv("AWS_REGION"):
        print("AWS region not specified. Please set the AWS_REGION environment variable or use the --region argument.")
        sys.exit(1)

    stack_id = args.stack_name
    output = {}

    # Step 1: Get current stack status
    status = get_stack_status(stack_id)
    output["StackStatus"] = status
    print(f"Stack status is {output['StackStatus']}")

    # Step 2: If the stack is in a rollback or failed state, find the resource that caused it
    if "ROLLBACK" in status or "FAILED" in status:
        print("Fetching the resource that likely caused the rollback...")
        failed_resource = get_failed_resource(stack_id)
        if failed_resource:
            output["FailedResource"] = failed_resource
            resource_path = " -> ".join(failed_resource["Path"])
            print("Resource that caused the rollback:")
            print(f"Resource Path: {resource_path}")
            print(f"Resource Type: {failed_resource['ResourceType']}")
            print(f"Status Reason: {failed_resource['StatusReason']}")
        else:
            print("No failed resources found.")
    else:
        print("Stack is not in a rollback or failed state.")

    # Output the result in JSON format
    print(json.dumps(output, indent=4))


if __name__ == "__main__":
    main()
