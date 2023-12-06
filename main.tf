### ~/cronjob-lambda/main.tf ###
################################
###--- Providers ---###

provider "aws" {
  version = "~> 5.0"
  region  = "us-east-2"
  profile = "test_account"                                              
}  

###--- IAM roles/policies/attachments ---###

resource "aws_iam_role" "lambda_role" {
	name = "ec2-instance-start-stop-lambda-role"
  
	assume_role_policy = jsonencode({
	  Version = "2012-10-17",
	  Statement = [{
		Action = "sts:AssumeRole",
		Effect = "Allow",
		Principal = {
		  Service = "lambda.amazonaws.com"
		}
	  }]
	})
  }
  
  resource "aws_iam_policy" "lambda_policy" {
	name        = "ec2-instance-start-stop-lambda-policy"
	description = "Policy for EC2 scheduling Lambda function"
	
	policy = jsonencode({
	  Version = "2012-10-17",
	  Statement = [
		{
			  "Sid": "VisualEditor0",
			  "Effect": "Allow",
			  "Action": [
				  "ec2:DescribeInstances",
				  "ec2:DescribeTags",
				  "ec2:Start*",
				  "ec2:Stop*"
			  ],
			  "Resource": "*"
		  },
		  {
			  "Sid": "VisualEditor1",
			  "Effect": "Allow",
			  "Action": [
				  "logs:CreateLogStream",
				  "logs:CreateLogGroup",
				  "logs:PutLogEvents"
			  ],
			  "Resource": "arn:aws:logs:*:*:*"
		  }
	  ]
	})
  }
  
  resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
	policy_arn = aws_iam_policy.lambda_policy.arn
	role       = aws_iam_role.lambda_role.name
  }

###--- EC2 instance ---###

resource "aws_instance" "tch_instance" {
	ami             = "ami-06d4b7182ac3480fa" 
	instance_type   = "t2.micro"
	#subnet_id       = aws_subnet.tch_subnet.id
  }

###--- Authentication: AWS key-pair ---###

resource "aws_key_pair" "tf_ec2_key-pair" {                                                               
	key_name = "tf_ec2-key"
	public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCISD+BixbcVT0q77oqNq9E8M4xAtCJTgiBK7X0MEPCW1eJdetJKx4VRUBCI1UUZkBODZw0bw3zTotGsL12izw0/SA74Au9WT3kL0SDucm0pX6QZOx984VyfrviuzAWJNDtWbd/Ue3MLEWaPHXbg2XEYbBp4tfXN4RDfVrpSJHxsg6niySrM9x33tpNCxNT0633xqvapUgO3b3BKKymE4H+mWLrKzGrAzvmB8IaTnFRwAantMwrYLv5QLp5K9VNN1tBWdhXkvL81v/5GPbqjFWrxWUKAIdBteSuo8MuK76EIHIF//coexdgm7NNlZsJfjZC2i2Od+V3fZD1uqovJf+3iCUT+4G0LwMP2EwztsTNJiYIE/g/k/n1KDd7KLp5J9+oej1Ln4ghY7tcRFBeRDmHSldcsct8xQxOqryatKSUKB8AVVxLSWeYg5lINrBQXmEz+sShA41uzMLNyOdSOHTqG932W3GJ9W/44JoFgLlJ1neX9ALJOXsL3L9JG2VukKs= ec2-user@ip-172-31-41-90.us-east-2.compute.internal"            
  }

###--- Lambda function ---###

data "archive_file" "python_code" {
    type        = "zip"
    source_dir  = "${path.module}/cronjob-lambda/"
    output_path = "${path.module}/cronjob-lambda/start_stop_lambda_function.zip"
}
resource "aws_lambda_function" "lambda-start-stop-ec2" {
    filename                       = "${path.module}/cronjob-lambda/start_stop_lambda_function.zip"
    function_name                  = "lambda-start-stop-ec2"
    role                           = aws_iam_role.lambda_role.arn
    handler                        = "start_stop_lambda_function.lambda_handler"
    runtime                        = "python3.9"
}


###--- Cloud watch ---###

resource "aws_cloudwatch_event_rule" "schedule_rule" {
	name        = "ec2-instance-nonprod-start-stop"
	description = "Schedule rule to trigger Lambda at specific times"
  
	schedule_expression = "cron(45 21 * * ? *)" # Adjust the schedule expression for 9 AM and 9 PM IST #GMT timze zone
  }
  
  resource "aws_cloudwatch_event_target" "schedule_target" {
	rule      = aws_cloudwatch_event_rule.schedule_rule.name
	target_id = "ec2-instance-nonprod-start-stop"
  
	arn = aws_lambda_function.lambda-start-stop-ec2.arn
  }


###--- EventBridge ---###

resource "aws_cloudwatch_event_rule" "cw-rule-start-ec2" {
    name = "cw-rule-start-ec2"
    description = "Trigger Lambda function to start EC2 instances"
    schedule_expression = "cron(40 21 * * ? *)"
}
resource "aws_cloudwatch_event_rule" "cw-rule-stop-ec2" {
    name = "cw-rule-stop-ec2"
    description = "Trigger Lambda function to stop EC2 instances"
    schedule_expression = "cron(55 21 * * ? *)"
}
resource "aws_cloudwatch_event_target" "lambda-start-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cw-rule-start-ec2.name
    input = <<JSON
    {
        "operation":"start"
    }
JSON
}
resource "aws_cloudwatch_event_target" "lambda-stop-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cw-rule-stop-ec2.name
    input = <<JSON
    {
        "operation":"stop"
    }
JSON
}
resource "aws_lambda_permission" "start-permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda-start-stop-ec2.arn
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cw-rule-start-ec2.arn
}
resource "aws_lambda_permission" "stop-permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda-start-stop-ec2.arn
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cw-rule-stop-ec2.arn
}