class test{
  file {'/home/admin/puppet_render.txt':
    ensure => present,
    content => "This was created by Puppet using test module",
    owner   => root,
    group   => root,
    mode    => 0644,
  }
}
