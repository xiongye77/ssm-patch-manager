resource "aws_ssm_document" "ssm-document" {
  name            = "PatchServers"
  document_type   = "Automation"
  document_format = "YAML"
  content         = <<EOF
---
description: "CSA SSM Automation - Patch instances"
schemaVersion: "0.3"
assumeRole: "{{AutomationAssumeRole}}"
parameters:
  Instance:
    type: "String"
    description: "(Required) ID of the Instance to patch. Only specify when not running from Maintenance Windows."
  AutomationAssumeRole:
    type: "String"
    description: "(Optional) The ARN of the role that allows Automation to perform the actions on your behalf."
    default: "${aws_iam_role.ssm-patching-role.arn}"
mainSteps:
- name: "CheckForOSUpdates"
  action: "aws:runCommand"
  timeoutSeconds: 7200
  maxAttempts: 3
  onFailure: "Abort"
  inputs:
    DocumentName: "AWS-RunPatchBaseline"
    InstanceIds:
    - "{{ Instance }}"
    Parameters:
      Operation: "Scan"
- name: "SleepWhileUpdate"
  action: "aws:sleep"
  inputs:
    Duration: "PT30S"
- name: "GetPatchState"
  action: "aws:executeAwsApi"
  maxAttempts: 3
  onFailure: "Abort"
  inputs:
    Service: "ssm"
    Api: "DescribeInstancePatchStates"
    InstanceIds:
    - "{{ Instance }}"
  outputs:
  - Name: "PatchesMissing"
    Selector: "$.InstancePatchStates[0].MissingCount"
    Type: "Integer"
- name: "SkipOrPatch"
  action: aws:branch
  inputs:
    Choices:
    - NextStep: UpdatePatchTags
      Variable: "{{GetPatchState.PatchesMissing}}"
      NumericEquals: 0
- name: "GetInstanceName"
  action: "aws:executeAwsApi"
  maxAttempts: 3
  onFailure: "Abort"
  inputs:
    Service: "ec2"
    Api: "DescribeTags"
    Filters:
    - Name: "resource-id"
      Values:
      - "{{ Instance }}"
    - Name: "key"
      Values:
      - "Name"
  outputs:
  - Name: "InstanceName"
    Selector: "$.Tags[0].Value"
    Type: "String"
- name: "createImagePrePatch"
  action: "aws:createImage"
  maxAttempts: 1
  onFailure: "Abort"
  inputs:
    InstanceId: "{{Instance}}"
    ImageName: "{{GetInstanceName.InstanceName}}-{{global:DATE_TIME}}"
    NoReboot: true
    ImageDescription: "Pre-Patch AMI, Roll back to me"
- name: "installMissingOSUpdates"
  action: "aws:runCommand"
  timeoutSeconds: 7200
  maxAttempts: 3
  onFailure: "Abort"
  inputs:
    DocumentName: "AWS-RunPatchBaseline"
    InstanceIds:
    - "{{Instance}}"
    Parameters:
      Operation: "Install"
- name: "SleepToCompleteInstall"
  action: "aws:sleep"
  inputs:
    Duration: "PT3M"
- name: "createImage"
  action: "aws:createImage"
  maxAttempts: 1
  onFailure: "Abort"
  inputs:
    InstanceId: "{{Instance}}"
    ImageName: "{{GetInstanceName.InstanceName}}-{{global:DATE_TIME}}"
    NoReboot: true
    ImageDescription: "Post Patch - Everything Worked"
- name: "UpdatePatchTags"
  action: "aws:createTags"
  maxAttempts: 1
  onFailure: "Abort"
  inputs:
    ResourceType: "EC2"
    ResourceIds:
    - "{{Instance}}"
    Tags:
    - Key: "LastPatched"
      Value: "{{global:DATE_TIME}}"
EOF
}

# SSM Automation execution role
resource "aws_iam_role" "ssm-patching-role" {
  name               = "ssm-patching-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
            "ec2.amazonaws.com",
            "lambda.amazonaws.com",
            "ssm.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ssm-patching-policy" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Action": "*",
          "Resource": "*"
      }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm-patching-role-attachment" {
  role       = aws_iam_role.ssm-patching-role.name
  policy_arn = aws_iam_policy.ssm-patching-policy.arn
}
