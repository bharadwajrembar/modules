$branch = 'dev'
$source = 'https://github.com/bharadwajrembar/modules.git'

exec { "/usr/bin/git clone -b $branch --single-branch $source /root/mods":
  timeout => 120,
}
