class new_mod {
  file { '/home/admin/puppet_new_mod.txt':
    ensure  => present,
    content => "This was generated by new_mod from $::environment\n from the main module\n",
    owner   => root,
    group   => root,
    mode    => 0644,
  }
}