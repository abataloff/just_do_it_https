#!/usr/bin/env bash

WWW_DIR='/var/www/'

log()
{
    echo $1
}

setupacmeclient()
{
    wget https://github.com/kelunik/acme-client/releases/download/v0.2.14/acme-client.phar
    chmod +x acme-client.phar
    echo -n "Введите e-mail для регистрации клиента: "
    read email;
    ./acme-client.phar setup --email=$email --server letsencrypt --storage ./storage
}

generatessl()
{
    if [ ! -f acme-client.phar ]; then
        setupacmeclient
    fi
    site=$1
    log "$(date +"%Y_%m_%d"): Начало генерации ключа для ${site}"
    ./acme-client.phar issue --domains $1 --path /var/www/$1 --server letsencrypt --storage ./storage
    cp -R ./storage/certs/acme-v01.api.letsencrypt.org.directory/$1/* /etc/nginx/ssl/$site
    log "$(date +"%Y_%m_%d"): Конец генерации ключа для ${site}"
}


initwkdir()
{
    dir="${WWW_DIR}/${1}/.well-khown"
    mkdir -p $dir
    chown -R www-data:www-data $dir
    find $dir -type d -exec chmod 755 {} \;

}

initssldir()
{
    dir="/etc/nginx/ssl/${1}"
    mkdir -p $dir
    chmod -R 700 $dir
}

addsite()
{
    site=$1
    echo $site >> sites

    # Иницициализировать папку .well-known
    initwkdir $site

    # Инициализировать папку ssl/site

    initssldir $site
    # Добавить nginx конфиг для site

    wk_ng="/etc/nginx/sites-available/${site}_well-khown"
    ln -s $wk_ng "/etc/nginx/sites-enabled/${site}_well-khown"
    echo "server {
	listen 80;

	server_name ${site};
	location /.well-known {
	    root ${WWW_DIR}/${1};
	}
    }" >> $wk_ng
    service nginx reload

    generatessl $site

    https_ng="/etc/nginx/sites-available/${site}_https"
    ln -s $https_ng "/etc/nginx/sites-enabled/${site}_https"
    echo "server {
	listen 443 ssl;
	server_name ${site};
        ssl_certificate /etc/nginx/ssl/${site}/cert.pem;
	ssl_certificate_key /etc/nginx/ssl/${site}/key.pem;
	location / {
	    proxy_pass http://${site};
	}
    }" >> $https_ng
    service nginx reload

}

echo -n "Введите доменные имена сайтов (через пробел или табуляцию): "
read sites;
for site in $sites
do
    addsite $site
done