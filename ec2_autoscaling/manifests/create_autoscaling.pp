def ec2_autoscaling::create_autoscaling(
$launch_config_name,
$ensure,
$user_data=undef,
$region,
$min_size,
$max_size,
$availability_zones,
$subnets,
$role
$environment
) {

  ec2_autoscalinggroup { $name:
    ensure   => $ensure,
    min_size => $min_size,
    max_size => $max_size,
    region   => $region,
    launch_configuration => $launch_config_name,
    availability_zones   => $availability_zones,
    subnets  => $subnets,
    tags     => {
      environment => $environment,
      role        => $role,
    }
  }
}
