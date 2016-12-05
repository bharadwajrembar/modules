def ec2_autoscaling::create_launchconfig(
$security_group_names,
$key_name,
$region,
$instance_type,
$image_id,
$vpc_name,
$user_data=undef,
)
{
  ec2_launchconfiguration { $name:
    ensure => $ensure,
    security_groups => $security_group_names,
    user_data       => template($user_data),
    key_name        => $key_name,
    region          => $region,
    instance_type   => $instance_type,
    image_id        => $image_id,
    vpc             => $vpc_name,
  }
}
