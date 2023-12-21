# This is a passing project where:
- EC2 instance based on T2-micro and RHEL is introduced with existing keys in the AWS as an ansible-host;
- EventBridge based cronjob is setup for: 
    - Tuesdays and Thursdays where the instance will be started at 6pm ET and stopped after 4 hours;
    - Saturdays and Sundays where the instance will be started at 9am ET and stopped after 4 hours;
- Lambda function automatically does the job in combination with IAM policies;
- The whole infrastructure will be provisioned with Terraform;
- Lambda function code is written in python and to be able to function with Terraform, is zipped as a .zip file.
