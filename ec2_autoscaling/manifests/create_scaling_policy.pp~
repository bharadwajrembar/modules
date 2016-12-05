def ec2_autoscaling::create_scaling_policy(
$region,
$ensure,
$autoscaling_name,
$scaling_adjustment,
$adjustment_type,
)
{
  ec2_scalingpolicy { $name:
    ensure   => $ensure,
    scaling_adjustment => $scaling_adjustment,
    region   => $region,
    adjustment_type    => $adjustment_type,
    autoscaling_group  => $autoscaling_name,
  }
}
