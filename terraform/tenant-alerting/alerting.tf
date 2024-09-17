locals {
  alertable_tenants = jsondecode(file("${path.module}/alertable_tenants.json"))

  # These are the alerts for paying customers that trigger pagerduty alerts
  status_alarm_rule     = join(" OR ", [for s in local.alertable_tenants.tenant_slugs : format("ALARM(\"%s-backstage-status-alarm\")", s)])
  front_door_alarm_rule = join(" OR ", [for s in local.alertable_tenants.tenant_slugs : format("ALARM(\"%s-front-door-alarm-health-check\")", s)])
}

resource "aws_sns_topic" "pagerduty_alerting" {
  name         = "pagerduty-alerting"
  display_name = "Alerts forwarded through Pagerduty"
}

resource "aws_sns_topic_subscription" "pagerduty_alerts" {
  topic_arn = aws_sns_topic.pagerduty_alerting.arn
  endpoint  = "https://events.eu.pagerduty.com/integration/21ee799beafc4705d18f39fc0d07/enqueue"
  protocol  = "https"
}
resource "aws_cloudwatch_composite_alarm" "customer_alert" {
  alarm_description = "This is a composite alarm with alarms from paying tenants"
  alarm_name        = "on-call-roadie-composite-alarm"

  alarm_actions = [aws_sns_topic.pagerduty_alerting.arn]
  ok_actions    = [aws_sns_topic.pagerduty_alerting.arn]

  alarm_rule = trimspace(local.status_alarm_rule)
}


resource "aws_sns_topic" "pagerduty_alerting_us_east" {
  provider     = aws.aws_global
  name         = "pagerduty-alerting_us-east-1"
  display_name = "UI availability alerts forwarded through to Pagerduty"
}
resource "aws_sns_topic_subscription" "pagerduty_alerts_us_east" {
  provider  = aws.aws_global
  topic_arn = aws_sns_topic.pagerduty_alerting_us_east.arn
  endpoint  = "https://events.eu.pagerduty.com/integration/21ee799beafc4705d187805f39fc0d07/enqueue"
  protocol  = "https"
}
resource "aws_cloudwatch_composite_alarm" "customer_alert_front_door" {
  alarm_description = "Composite alarm for all paying tenants if healthcheck of their tenant fails"
  alarm_name        = "on-call-roadie-front-door-alarm"
  provider          = aws.aws_global

  alarm_actions = [aws_sns_topic.pagerduty_alerting_us_east.arn]
  ok_actions    = [aws_sns_topic.pagerduty_alerting_us_east.arn]

  alarm_rule = trimspace(local.front_door_alarm_rule)
}
