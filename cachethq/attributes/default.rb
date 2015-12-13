cachethq = default['cachethq']

cachethq['php']['version'] = '55'
cachethq['php']['modules'] = ['php55-intl', 'php55-mbstring', 'php55-mcrypt', 'php55-mysqlnd', 'php55-pdo', 'php55-pecl-apcu', 'php55-xml', 'php55-fpm']
cachethq['packages'] = ['git', 'php55', 'openssl', 'nginx', 'collectd-nginx']
cachethq['epel']['packages'] = ['nodejs', 'npm']
cachethq['repo'] = 'https://github.com/cachethq/Cachet.git'
cachethq['db']['driver'] = 'sqlite'
cachethq['db']['name'] = 'cachethq'

nginx = cachethq['nginx']
nginx['confdir'] = '/etc/nginx/conf.d/'
nginx['docroot'] = '/usr/share/nginx/html/'
nginx['server_name'] = 'cachethq.server.url'
nginx['logs_dir'] = '/var/log/nginx/'
cachethq['install_dir'] = nginx['docroot'] + 'cachethq/'
cachethq['logs']['access'] = nginx['logs_dir'] + 'cachethq.access.log'
cachethq['logs']['error'] = nginx['logs_dir'] + 'cachethq.error.log'
cachethq['db']['file'] = "#{cachethq['install_dir']}app/database/#{cachethq['db']['name']}.sqlite"

fpm = cachethq['php-fpm']
fpm['config'] = '/etc/php-fpm-5.5.conf'
fpm['confdir'] = '/etc/php-fpm-5.5.d/'
fpm['logdir'] = '/var/log/php-fpm/5.5/'
fpm['socket'] = '/var/run/php-fpm/cachethq.sock'

npm = cachethq['npm']
npm['modules'] = %w(bower gulp)
