node default {
  file { '/home/admin/sample.txt':
    ensure  => present,
    content => 'This is created by Puppet',
    owner   => root,
    group   => root,
    mode    => 0644,
  }
  include ::test
  include ::new_mod
}
