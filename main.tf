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
	#arn 			= aws_key_pair.tf_ec2_key-pair.arn
	#arn				= arn:aws:ec2:us-east-2:528736153640:key-pair/mykeyforclass
	ami             = "ami-0ef50c2b2eb330511" 
	instance_type   = "t2.micro"
	key_name 		= "tf_ec2_key-pair"

	#attach arn of the key here
	#subnet_id       = aws_subnet.tch_subnet.id

	tags_all                             = {
        "Name" = "ansible-host"
        }
  }

###--- Authentication: AWS key-pair ---###

#resource "aws_key_pair" "tf_ec2_key-pair" {                                                               
#	key_name = "tf_ec2_key-pair"
#	public_key = "ssh-rsa AAAAEAAAattT...tjqA/haSsAdSy1qNCTDKrM1vQahJ29kNcPId1+XMqSr/gVN5BAdDhTWQxMHC7DKnVh7JhFrdXYZhknPOKHZr8hG+peSjL7TwkRSLwsFfPAURwNdTv8nUCZGxwlZAKs26BlRrmK6RsG4ioKcGpj06gte08w1cmxsX8OvKkDVGwMtIPNbiPLTzX9ReioU4BeLv"            
#  }

###--- Lambda function ---###

data "archive_file" "python_code" {
    type        = "zip"
    source_dir  = "${path.module}/py_code/"
    output_path = "${path.module}/cronjob-lambda/start_stop_lambda_function.zip"
}
resource "aws_lambda_function" "lambda-start-stop-ec2" {
    filename                       = "${path.module}/cronjob-lambda/start_stop_lambda_function.zip"
    function_name                  = "lambda-start-stop-ec2"
    role                           = aws_iam_role.lambda_role.arn
    handler                        = "start_stop_lambda_function.lambda_handler"
    runtime                        = "python3.9"
}

###--- EventBridge ---###
## Tue,Thu rule

resource "aws_cloudwatch_event_rule" "cwt-rule-start-ec2" {
    name = "cwTT-rule-start-ec2"
    description = "Trigger Lambda function to start EC2 instances"
    schedule_expression = "cron(00 22 ? * Tue,Thu *)"
}
resource "aws_cloudwatch_event_rule" "cwt-rule-stop-ec2" {
    name = "cwTT-rule-stop-ec2"
    description = "Trigger Lambda function to stop EC2 instances"
    schedule_expression = "cron(00 02 ? * Tue,Thu *)"
}

resource "aws_cloudwatch_event_target" "lambda-start-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cwt-rule-start-ec2.name
    input = <<JSON
    {
        "operation":"start"
    }
JSON
}
resource "aws_cloudwatch_event_target" "lambda-stop-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cwt-rule-stop-ec2.name
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
    source_arn = aws_cloudwatch_event_rule.cwt-rule-start-ec2.arn
}
resource "aws_lambda_permission" "stop-permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda-start-stop-ec2.arn
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cwt-rule-stop-ec2.arn
}

## Sat-Sun

resource "aws_cloudwatch_event_rule" "cws-rule-start-ec2" {
    name = "cwSS-rule-start-ec2"
    description = "Trigger Lambda function to start EC2 instances"
	schedule_expression = "cron(00 22 ? * Sat,Sun *)"
}
resource "aws_cloudwatch_event_rule" "cws-rule-stop-ec2" {
    name = "cwSS-rule-stop-ec2"
    description = "Trigger Lambda function to stop EC2 instances"
	schedule_expression = "cron(00 02 ? * Sat,Sun *)"
}

resource "aws_cloudwatch_event_target" "lambdas-start-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cws-rule-start-ec2.name
    input = <<JSON
    {
        "operation":"start"
    }
JSON
}
resource "aws_cloudwatch_event_target" "lambdas-stop-ec2" {
    arn = aws_lambda_function.lambda-start-stop-ec2.arn
    rule = aws_cloudwatch_event_rule.cws-rule-stop-ec2.name
    input = <<JSON
    {
        "operation":"stop"
    }
JSON
}
resource "aws_lambda_permission" "starts-permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda-start-stop-ec2.arn
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cws-rule-start-ec2.arn
}
resource "aws_lambda_permission" "stops-permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda-start-stop-ec2.arn
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.cws-rule-stop-ec2.arn
}