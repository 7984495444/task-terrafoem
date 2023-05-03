provider "aws" {
  region  = "us-east-1"
 }
# Creating the autoscaling launch configuration that contains AWS EC2 instance details
resource "aws_launch_configuration" "aws_autoscale_conf" {
# Defining the name of the Autoscaling launch configuration
  name          = "web_config"
# Defining the image ID of AWS EC2 instance
  image_id      = "ami-0aa2b7722dc1b5612"
# Defining the instance type of the AWS EC2 instance
  instance_type = "t2.micro"
# Defining the Key that will be used to access the AWS EC2 instance
  key_name = "hir-nort"
}

# Creating the autoscaling group within us-east-1a availability zone
resource "aws_autoscaling_group" "mygroup" {
# Defining the availability Zone in which AWS EC2 instance will be launched
  availability_zones        = ["us-east-1a"]
# Specifying the name of the autoscaling group
  name                      = "autoscalegroup"
# Defining the maximum number of AWS EC2 instances while scaling
  max_size                  = 5
# Defining the minimum number of AWS EC2 instances while scaling
  min_size                  = 3
# Grace period is the time after which AWS EC2 instance comes into service before checking health.
  health_check_grace_period = 30
# The Autoscaling will happen based on health of AWS EC2 instance defined in AWS CLoudwatch Alarm 
  health_check_type         = "EC2"
# force_delete deletes the Auto Scaling Group without waiting for all instances in the pool to terminate
  force_delete              = true
# Defining the termination policy where the oldest instance will be replaced first 
  termination_policies      = ["OldestInstance"]
# Scaling group is dependent on autoscaling launch configuration because of AWS EC2 instance configurations
  launch_configuration      = aws_launch_configuration.aws_autoscale_conf.name
}
# Creating the autoscaling schedule of the autoscaling group
resource "aws_autoscaling_schedule" "mygroup_schedule" {
  scheduled_action_name  = "autoscalegroup_action"
# The minimum size for the Auto Scaling group
  min_size               = 5
# The maxmimum size for the Auto Scaling group
  max_size               = 3
# Desired_capacity is the number of running EC2 instances in the Autoscaling group
  desired_capacity       = 2
# defining the start_time of autoscaling if you think traffic can peak at this time.
  start_time             = "2022-02-09T18:00:00Z"
  autoscaling_group_name = aws_autoscaling_group.mygroup.name
}

# Creating the autoscaling policy of the autoscaling group
resource "aws_autoscaling_policy" "mygroup_policy" {
  name                   = "autoscalegroup_policy"
# The number of instances by which to scale.
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
# The amount of time (seconds) after a scaling completes and the next scaling starts.
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.mygroup.name
}
# Creating the AWS CLoudwatch Alarm that will autoscale the AWS EC2 instance based on CPU utilization.
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
# defining the name of AWS cloudwatch alarm
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
# Defining the metric_name according to which scaling will happen (based on CPU) 
  metric_name = "CPUUtilization"
# The namespace for the alarm's associated metric
  namespace = "AWS/EC2"
# After AWS Cloudwatch Alarm is triggered, it will wait for 60 seconds and then autoscales
  period = "60"
  statistic = "Average"
# CPU Utilization threshold is set to 10 percent
  threshold = "10"
  alarm_actions = [
        "${aws_autoscaling_policy.mygroup_policy.arn}"
    ]
dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.mygroup.name}"
  }
}
module "vote_service_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "user-service"
  description = "Security group for user-service with custom ports open within VPC, and PostgreSQL publicly open"
  vpc_id      = "vpc-12345678"

  ingress_cidr_blocks      = ["10.10.0.0/16"]
  ingress_rules            = ["https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8090
      protocol    = "tcp"
      description = "User-service ports"
      cidr_blocks = "10.10.0.0/16"
    },
    {
      rule        = "postgresql-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}
resource "aws_s3_bucket" "example" {
  bucket = "s3-bucket"
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.example.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["123456789012"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}/*",
    ]
  }
}