resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.name}-guardduty-findings"
  description = "Forward GuardDuty findings to the operations notification topic."
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_findings" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "guardduty-findings-sns"
  arn       = aws_sns_topic.alarms.arn
}

data "aws_iam_policy_document" "sns_events" {
  statement {
    sid       = "AllowGuardDutyEventBridge"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.guardduty_findings.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "events" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.sns_events.json
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.name}-ecs-cpu-high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
  alarm_actions = [aws_sns_topic.alarms.arn]
  tags          = { Name = "${var.name}-ecs-cpu-high" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${var.name}-ecs-memory-high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
  alarm_actions = [aws_sns_topic.alarms.arn]
  tags          = { Name = "${var.name}-ecs-memory-high" }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "healthy_hosts" {
  alarm_name          = "${var.name}-alb-no-healthy-targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  treat_missing_data = "breaching"
  alarm_actions      = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "jenkins_cpu" {
  count               = var.jenkins_enabled ? 1 : 0
  alarm_name          = "${var.name}-jenkins-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = var.jenkins_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags                = { Name = "${var.name}-jenkins-cpu-high" }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-operations"
  dashboard_body = jsonencode({
    widgets = concat([
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title  = "ECS service CPU and memory"
          region = var.region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.service_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title  = "ALB target response and errors"
          region = var.region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.load_balancer_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.load_balancer_arn_suffix, "TargetGroup", var.target_group_arn_suffix]
          ]
          period = 60
        }
      }
      ], var.jenkins_enabled ? [
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          title  = "Jenkins controller CPU"
          region = var.region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.jenkins_instance_id]
          ]
          period = 300
        }
      }
    ] : [])
  })
}
