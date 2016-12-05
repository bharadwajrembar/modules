def ec2_autoscaling::create_cloudwatch_alarm(
$ensure,
$metric,
$statistic,
$namespace,
$period='60',
$threshold='40',
$comparision_operator,
$region
$policy_name,
)
{
  cloudwatch_alarm { $name:
    ensure    => $ensure,
    metric    => $metric,
    namespace => $namespace,
    statistic => $statistic,
    period    => $period,
    threshold => $threshold,
    comparision_operator => $comparision_operator,
    region    => $region,
    alarm_actions => $policy_name,
  }
}
