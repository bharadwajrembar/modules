def ec2_autoscaling::create_lifecycle_hook(
$autoscaling_name,
$region,
$ensure,
$heartbeat_timeout='900',
)
{
  ec2_lifecycle_hook { $name:
    ensure                  => $ensure,
    auto_scaling_group_name => $autoscaling_name,
    default_result          => 'ABANDON',
    heartbeat_timeout       => $heartbeat_timeout,
    lifecycle_transition    => 'autoscaling:EC2_INSTANCE_LAUNCHING',
    region                  => $region,
  }
}
