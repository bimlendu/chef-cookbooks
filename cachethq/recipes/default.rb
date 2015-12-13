#
# Cookbook Name:: cachethq
# Recipe:: default
#
# All rights reserved - Do Not Redistribute
#

log "***** In recipe #{cookbook_name}:#{recipe_name} *****"

cachethq = node.default['cachethq']
nginx = cachethq['nginx']
fpm = cachethq['php-fpm']
npm = cachethq['npm']

log '**** Installing required packages ****'
cachethq['packages'].each do |pkg|
  log "*** Installing #{pkg} ***"
  yum_package pkg
end

cachethq['epel']['packages'].each do |pkg|
  log "*** Installing #{pkg} ***"
  yum_package pkg do
    options '--enablerepo=epel'
  end
end

log '**** Installing required php modules ****'
cachethq['php']['modules'].each do |mod|
  log "*** Installing php module #{mod} ***"
  package mod
end

log '**** Deleting default php-fpm config file ****'
file fpm['confdir'] + 'www.conf' do
  action :delete
end

log '**** Setting up php-fpm config for cachethq ****'
template fpm['confdir'] + 'php-fpm-cachethq.conf' do
  source 'php-fpm-cachethq.conf.erb'
  owner 'nginx'
  group 'nginx'
  mode 0644
  variables(
    name: 'cachethq',
    socket: fpm['socket'],
    logdir: fpm['logdir']
  )
  notifies :reload, 'service[php-fpm]'
end

log '**** Installing required nodejs modules ****'
npm['modules'].each do |mod|
  log "*** Installing nodejs module #{mod} ***"
  execute "npm install -g #{mod}" do
    action :run
    not_if { ::File.exist?("/usr/bin/#{mod}") }
  end
end

log '**** Install composer ****'
bash 'php composer' do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  EOH
  not_if { ::File.exist?('/usr/local/bin/composer') }
end

log '**** Cloning cachethq repo from github ****'
git cachethq['install_dir'] do
  repository cachethq['repo']
  action :checkout
end

log '**** Setting up production db properties ****'
template cachethq['install_dir'] + '.env.php' do
  source 'env.php.erb'
  owner 'nginx'
  group 'nginx'
  mode 0644
end

log '**** Creating database sqlite file ****'
file cachethq['db']['file'] do
  action :create
  not_if { ::File.exist?(cachethq['db']['file']) }
end

['/tmp/composer.install.log', '/tmp/php.artisan.migrate.log', '/tmp/npm.install.log', '/tmp/bower.install.log', '/tmp/gulp.log'].each do |log_file|
  file log_file do
    action :delete
  end
end

log '**** Installing CachetHQ dependencies ****'
CachetHQ_install = {
  'composer' => {
    'cmd' => '/usr/local/bin/composer install --no-dev -o -vvv',
    'log' => '/tmp/composer.install.log',
    'msg' => '*** Installing dependencies that CachetHQ requires ***'
  },
  'artisan' => {
    'cmd' => 'php artisan migrate --force',
    'log' => '/tmp/php.artisan.migrate.log',
    'msg' => '*** Running database migrations ***'
  },
  'npm' => {
    'cmd' => 'npm install',
    'log' => '/tmp/npm.install.log',
    'msg' => '*** Installing CachetHQ nodejs dependencies ***'
  },
  'bower' => {
    'cmd' => 'bower install',
    'log' => '/tmp/bower.install.log',
    'msg' => '*** Installing CachetHQ bower dependencies ***'
  },
  'gulp' => {
    'cmd' => 'gulp',
    'log' => '/tmp/gulp.log',
    'msg' => '*** Building CachetHQ assets ***'
  }
}

CachetHQ_install.each do |component, config|
  log config['msg']
  command = config['cmd']
  logfile = config['log']
  bash "#{command} &> #{logfile}" do
    cwd cachethq['install_dir']
    user 'nginx'
    group 'nginx'
    environment('ENV' => 'production', 'HOME' => '/var/lib/nginx')
  end
end

log '**** Setting up nginx config for CachetHQ ****'
template nginx['confdir'] + 'CachetHQ.conf' do
  source 'cachethq.conf.erb'
  owner 'nginx'
  group 'nginx'
  mode 0644
  variables(
    server_name: node['cachethq']['nginx']['server_name'],
    install_dir: cachethq['install_dir'],
    access_log: cachethq['logs']['access'],
    error_log: cachethq['logs']['error'],
    fpm_socket: fpm['socket']
  )
  notifies :reload, 'service[nginx]'
end

log '**** Correcting permissions on log and install directories ****'
[fpm['logdir'], cachethq['install_dir']].each do |dir|
  execute "chown -R nginx:nginx #{dir}" do
    action :run
  end
end

service 'php-fpm' do
  supports status: true, restart: true, reload: true
  action :start
end

service 'nginx' do
  supports status: true, restart: true, reload: true
  action :start
end

log "***** Recipe #{cookbook_name}:#{recipe_name} ends here. *****"
