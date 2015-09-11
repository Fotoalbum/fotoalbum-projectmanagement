class requirements {
  group { "puppet": ensure => "present", }
  package { ["python-software-properties", "git"]:  ensure => "installed" }
}

class roles::php($version = 'installed') {

  include php
  include php::params
  include php::pear
  include php::composer
  include php::composer::auto_update

  # Extensions must be installed before they are configured
  Php::Extension <| |> -> Php::Config <| |>

  # Ensure base packages is installed in the correct order
  # and before any php extensions
  Package['php5-common']
  -> Package['php5-dev']
  -> Package['php5-cli']
  -> Php::Extension <| |>

  #mongo fix for ini file
  file { '/etc/php5/fpm/conf.d/20-mongo.ini':
    ensure => 'link',
    target => '/etc/php5/mods-available/mongo.ini',
  }
  file { '/etc/php5/cli/conf.d/20-mongo.ini':
    ensure => 'link',
    target => '/etc/php5/mods-available/mongo.ini',
  }

  class {
    # Base packages
    [ 'php::dev', 'php::cli' ]:
      ensure => $version;

    # PHP extensions
    [
      'php::extension::curl', 'php::extension::gd', 'php::extension::imagick',
      'php::extension::mysql', 'php::extension::redis', 'php::extension::opcache',
      'php::extension::gearman'
    ]:
      ensure => $version;

    ['php::extension::xdebug']:
      ensure => $version,
      settings => [ 'set .anon/zend_extension xdebug.so',
                    'set .anon/xdebug.remote_host 12.0.0.1',
                    'set .anon/xdebug.remote_enable 1'];

    [ 'php::extension::igbinary' ]:
      ensure => installed;

    # Sander: broken for fpm, ps aux | grep php and kill the fpm process then do a service restart
    [ 'php::extension::mcrypt' ]:
      ensure => $version;

    # Sander: Symlinks are missing. so manual here
    [ 'php::extension::mongo']:
      ensure => $version,
      before => [File['/etc/php5/fpm/conf.d/20-mongo.ini'], File['/etc/php5/cli/conf.d/20-mongo.ini']];
  }

  # Install the INTL extension
  php::extension { 'php5-intl':
    ensure    => $version,
    package   => 'php5-intl',
    provider  => 'apt'
  }

  create_resources('php::config', hiera_hash('php_config', {}))
  create_resources('php::cli::config', hiera_hash('php_cli_config', {}))
}

class roles::php_fpm($version = 'installed') {

  include php
  include php::params

  class { 'php::fpm':
    ensure => $version,
    emergency_restart_threshold  => 5,
    emergency_restart_interval   => '1m',
    rlimit_files                 => 32768,
    events_mechanism             => 'epoll'
  }

  create_resources('php::fpm::pool',  hiera_hash('php_fpm_pool', {}))
  create_resources('php::fpm::config',  hiera_hash('php_fpm_config', {}))

  Php::Extension <| |> ~> Service['php5-fpm']

  # needed?
  exec { "restart-php5-fpm":
    command  => "service php5-fpm restart",
    schedule => hourly,
    require => Class['php::fpm']
  }
}

class apache_install {

  # Prefork is needed for PHP support
  class { 'apache':
    mpm_module          => 'event',
    default_mods        => false,
    default_confd_files => false,
    default_vhost       => true
  }
  

  # Enable rewrite module
  class { '::apache::mod::rewrite': }
  class { '::apache::mod::mime': }
  class { '::apache::mod::actions': }
  class { '::apache::mod::fastcgi': }
  class { '::apache::mod::auth_basic': }
  class { '::apache::mod::dir': }
  class { '::apache::mod::deflate': }

  # Enable env module (use generic syntax because the class is missing)
  # https://tickets.puppetlabs.com/browse/MODULES-1322
  apache::mod {"env": }
  apache::mod {"setenvif": }

  # Create vhost for development, with FPM

  # Bug 1: SendFile is not working on vagrant box!! so we must disable it
  #@see http://stackoverflow.com/questions/6298933/shared-folder-in-virtualbox-for-apache/6511441#6511441
  apache::vhost {'10.0.0.2':
    port     => 80,
    docroot  => '/vagrant/public',
    override => ['All'],
    directoryindex => 'index.php',
    aliases => [{alias => '/php5-fcgi', path => '/usr/lib/cgi-bin/php5-fcgi'}],
    fastcgi_server => '/usr/lib/cgi-bin/php5-fcgi',
    fastcgi_socket => '/var/run/php5-fpm.sock',
    fastcgi_dir => '/usr/lib/cgi-bin/php5-fcgi',
    serveraliases => ['dev.fotoalbum-lavarel.nl'],
    custom_fragment => '
      Action application/x-httpd-php5 /php5-fcgi
      AddType application/x-httpd-php5 .php
      EnableSendfile off
    '
  }

}

class project_initializer {
  # Let composer handle our libraries
  exec { "composer_dependency_install":
    command => "composer install",
    user => "vagrant",
    cwd  => '/vagrant',
    environment => [ "HOME=/home/vagrant" ]
  }
  exec { "npm_dependency_install":
    command => "npm install",
    user => "root",
    cwd  => '/vagrant',
    environment => [ "HOME=/home/vagrant" ]
  }
}

node default {

  Exec {
    path => [ '/usr/local/bin/', '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  }

  # Gearman
  class { 'gearman':
    service_enable => true,
    service_ensure => 'running'
  }

  # Supervisord for tasks
  class { 'supervisord':
    install_pip => true
  }
  supervisord::program { 'gulp_watch':
    command     => 'gulp watch',
    priority    => '100',
    redirect_stderr => true,
    directory   => '/vagrant',
    environment => {
      'HOME'   => '/home/vagrant',
      'PATH'   => '/usr/local/bin/:/bin/:/sbin/:/usr/bin/:/usr/sbin/'
    },
    require => Package['gulp']
  }
  supervisord::program { 'genghisapp':
    command     => 'genghisapp -F',
    priority    => '100',
    require     => Package['genghisapp'],
    environment => {
      'HOME'   => '/home/vagrant',
    }
  }

  package { 'genghisapp':
    ensure => present,
    provider => 'gem'
  }

  # Mongo
  class {'::mongodb::globals':
    manage_package_repo => true,
  } ->
  class { '::mongodb::server':
    auth    => false,
    ensure  => 'present',
    bind_ip => ['127.0.0.1'],
  } ->
  class {'::mongodb::client': }

  mongodb::db { 'fotoalbum':
    user => 'fotoalbum',
    password_hash => '6fdcc22bd0064a729b6ff05151ffbb43',
  }

  apt::pin { 'sid': priority => 100 }

  class { roles::php: } ->
  class { roles::php_fpm: }

  # Needed for gulp
  package{'libnotify-bin': }
  class { 'nodejs':
  }
  package { 'gulp':
    ensure   => present,
    provider => 'npm',
    require => [Package['libnotify-bin'], Class['nodejs']]
  }

  class { requirements: } ->
  class { apache_install: } ->
  class { 'composer':
    auto_update => true
  } ->
  class { project_initializer: }
}