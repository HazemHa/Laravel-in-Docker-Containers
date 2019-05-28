#!/bin/bash

# Author : Hazem HA
# Copyright (c) Hazem HA

echo "Enter port number for nginx :"
read Pnginx

echo "Enter port number for Laravel App :"
read PlaravelApp


#check if ports are used or not
ports=`docker ps --format "{{.Ports}}"`
if [[ $ports == *"0.0.0.0:${PlaravelApp}"* || $ports == *"->${Pnginx}"*  ]]; then
  echo -e "\e[31m0.0.0.0:${PlaravelApp}->${Pnginx} are already used"
  exit 0
fi

#if not exist create folder
if [ ! -d "logs" ]; then
  mkdir logs;
  echo -e "\e[32mcreate folder logs"

fi

if [ ! -d "nginx" ]; then
  mkdir -p nginx/conf.d;
   echo -e "\e[32mcreate folder nginx/conf.d"
fi

if [ ! -d "www" ]; then
  mkdir www;
   echo -e "\e[32mcreate folder www"
fi



#check if node modules created or not
if [ -d "node_modules" ] 
then
#if we found old version remove it and install it
 echo -e "\e[31mremove old version from npm"

 createNode= true

rm -f package-lock.json
rm -rf node_modules
echo -e "\e[36mset flag to create nodejs"


else 
 echo -e "\e[91mno nodejs modules"

 createNode= false

fi


FILE=.env
projectName=${PWD##*/}
if test -f "$FILE"; then
    echo -e "\e[34m$FILE exist"
     sed -i "s/DB_HOST=127.0.0.1/DB_HOST=${projectName}_mysql_1/g" $FILE
    echo -e "\e[32m$FILE updated .."


    declare -A dbInfomySqlContainer
    dbInfo=`cat $FILE | grep "DB"`
    IFS=$'\n'
    for item in $dbInfo
                        do
  IFS='=' # space is set as delimiter
  read -ra ADDR <<< "$item" 
   dbInfomySqlContainer[${ADDR[0]}]=${ADDR[1]}
     done

   

    else
     echo -e "\e[91m$FILE does not exist"

fi



##
## check if laravel app created or not
# if it not create , then create one
if [ -d "bootstrap" ] 
then
#set flag we found laravel app
echo -e "\e[34mset flag to update app"

createOne= false
#move all content to www folder
#shopt -s extglob
mv * .* www
chown -R root:root www
chmod -R 755 www
cd www
mv logs ..
mv nginx ..
mv dockerLaravelApp.sh ..
chmod -R 777 storage
cd ..
#mv docker-compose.yml ..

else
echo -e "\e[34mset flag to create app"

     createOne= true
fi

#create file docker-composer
echo "version: '2'
services:
    nginx:
        image: nginx:mainline-alpine
        ports:
            - "$PlaravelApp:$Pnginx"
        volumes:
            - ./www:/var/www
            - ./nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf
            - ./logs/nginx:/var/log/nginx
        links: 
            - php7fpm 
        depends_on: 
            - php7fpm
            - mysql
    artisan:
        image: wiwatsrt/docker-laravel-artisan
        volumes:
            - ./www:/var/www
        links: 
            - mysql
        depends_on: 
            - mysql
    composer:  
        image: wiwatsrt/docker-laravel-composer
        volumes:
            - ./www:/var/www
    php7fpm:
        image: wiwatsrt/docker-laravel-php7fpm
        volumes:
            - ./www:/var/www
        links:
            - mysql
        depends_on: 
            - mysql
    mysql:
        image: mysql:5.7
        volumes:
            - db_data:/var/lib/mysql
            - ./logs/mysql:/var/log/mysql
        environment: 
            - MYSQL_ROOT_PASSWORD=rootsecret
            - MYSQL_DATABASE=${dbInfomySqlContainer[DB_DATABASE]}
            - MYSQL_USER=${dbInfomySqlContainer[DB_USERNAME]}
            - MYSQL_PASSWORD=${dbInfomySqlContainer[DB_PASSWORD]}
    nodejs:  
        image: wiwatsrt/docker-laravel-nodejs
        volumes:
            - ./www:/var/www
volumes:
    db_data:" >> docker-compose.yml 

 echo -e '\e[32mcreate file docker-compose.yml'

#create nginx config
echo "server {
    listen       $Pnginx;
    server_name  localhost;
    root        /var/www/public;
    index       index.php;
charset utf-8;
    access_log  /var/log/nginx/localhost.access.log  main;
location / {
        try_files \$uri \$uri/ /index.php\$query_string;
    }
location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php7fpm:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
# redirect server error pages to the static page /50x.html
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}" >> nginx/conf.d/default.conf

 echo -e '\e[32mcreate file default.conf'


#create new laravel app
if [ "$createOne" = true ];
then
 echo -e '\e[32mcreate new laravel app'
 docker-compose run --rm composer create-project --prefer-dist laravel/laravel . 
 
 #if is exist then update old laravel app
 else 
  echo -e "\e[32mupdate old laravel app"
  docker-compose run --rm composer update
  
fi



#if not is exist then install

if [ "$createNode" = true ];
then
 echo -e "\e[32minstall npm ${createNode}"
 docker-compose run --rm nodejs npm install
 docker-compose run --rm nodejs npm run dev 
 #if is exist then update old laravel app
 else 
   echo -e "\e[91mno npm , continue"
fi




#build image
   docker-compose up -d --build
   #containerID=`docker ps -aqf "name=${projectName}_nginx_1"`
   #echo "$containerID"
   #docker exec -it ${containerID} sh
   #cd /var/www
