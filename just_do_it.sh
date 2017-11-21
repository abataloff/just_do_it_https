#!/usr/bin/env bash

WWW_DIR='/var/www'

log()
{
    echo "$(date +"%Y_%m_%d %H:%M:%S"): ${1}"
}

setupacmeclient()
{
    wget https://github.com/kelunik/acme-client/releases/download/v0.2.14/acme-client.phar
    chmod +x acme-client.phar
    echo -n "Введите e-mail для регистрации клиента: "
    read email;
    ./acme-client.phar setup --email=$email --server letsencrypt --storage ./storage
}

updatessl()
{
    site=$1
    log "Начало генерации и обновления ключа для ${site}"
    ./acme-client.phar issue --domains $1:10987 --path $WWW_DIR/$1 --server letsencrypt --storage ./storage
    cp -R ./storage/certs/acme-v01.api.letsencrypt.org.directory/$1/* /etc/nginx/ssl/$site
    log "Окончание генерации и обновления ключа для ${site}"
}

updateallssl()
{
    log "Старт обновления всех сертификатов"
    for site in $(<sites)
    do
        updatessl $site
    done
    log "Окончание обновления всех сертификатов"
}

initwkdir()
{
    dir="${WWW_DIR}/${1}/.well-known"
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

    # Иницициализация папки .well-known
    initwkdir $site

    # Инициализация папки ssl/site
    initssldir $site

# TODO: Реализовать возможность раздачи папки well_known
#    # Добавление nginx конфига для site
#    wk_ng="/etc/nginx/sites-available/${site}_well-known"
#    ln -s $wk_ng "/etc/nginx/sites-enabled/${site}_well-known"
#    echo "server {
#	listen 80;
#
#	server_name ${site};
#	location /.well-known {
#	    root ${WWW_DIR}/${1};
#	}
#    }" >> $wk_ng
#    service nginx reload

    # Генерация SSL для сайта
    updatessl $site
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

#    TODO: Задать корректные права на папки и файлы
}

addsites()
{
    # Если необходимо устанавливаем клиент
    if [ ! -f acme-client.phar ]; then
        echo "У вас не установлен acme клиент. Сейчас начнется его установка."
        setupacmeclient
    fi

    # Если необходимо устанавливаем cron на обновление
    crontab -l | grep -q 'just_do_it.sh' || setcrontab

    echo -n "Введите доменные имена сайтов (через пробел или табуляцию): "
    read sites;
    for site in $sites
    do
        addsite $site
    done
}

setcrontab()
{
    crontab -l > mycron
    echo "0 0 1 */3 * /bin/bash $(pwd)/just_do_it.sh -update-all-ssl >> $(pwd)/log" >> mycron
    crontab mycron
    rm mycron
}

helpText="
Команды:
    -h - отображение справки
    -add-sites - Добавление новых сайтов (Команда по умолчанию)
    -update-all-ssl - Обновить все SSL для ранее добавленных сайтов"

if [ $# -eq 0 ]
    then
        addsites
    else
    case $@ in
        -add-sites )
            addsites;;
        -update-all-ssl )
            updateallssl ;;
        -h )
            echo "$helpText" ;;
        * )
            echo "Нераспознаная команда ${arg}. Вызов справки -h";;
    esac
fi