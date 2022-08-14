#! /bin/bash
## Variables section
install_dir="/var/www"
clone_url=https://nipun.haldar:glpat-c4E4gRLpPExSAYezDqug@project.samarth.ac.in/product/software/uims.git
universitylist="{{ssm:newparameter}}"
db_host=abccde
sentry_dsn=xyzxyz
redis_host=asdfghj
admin_user=admin
admin_user_password=dvp-1-GIT
rds_host=rds-database.cdtk6seda0er.ap-south-1.rds.amazonaws.com



set -e                      #This will cause the shell to exit immediately if a simple command exits with a nonzero exit value.
set -o pipefail
if [ -d $install_dir/uims ];
then
    common_repo=$install_dir/uims
else
    # git -C $install_dir clone $clone_url --depth 1
    git -C $install_dir clone $clone_url -b deploy --single-branch
fi
echo $universitylist
for university in ${universitylist//,/ }
do
            # call your procedure/other scripts here below
        echo "$university"
        db_password=$(openssl rand -base64 25 | tr -d "=/" | cut -c1-20)
        echo $db_password
        db_username=${university}_usr
        echo $db_username
        db_genname=dbcu_${university}


        ##Setup HTML Folder
        mkdir -p $install_dir/html/$university/uims/
        cp -R $install_dir/uims/web/* $install_dir/html/$university/uims/
        mkdir -p $install_dir/html/$university/uims/assets/
        mkdir -p $install_dir/html/$university/uims/uploads/uims/
        cd $install_dir/html/$university/uims/uploads/uims/
        mkdir -p affiliation cas ccs cfs enhousing essential estate fmts grievance health hrms ims legal leave ocm  payroll placement profile profile/user rpms rti sample_format/excels security sports training transport vendor
        chown -R apache:apache $install_dir/html/$university/uims/assets/
        chown -R apache:apache $install_dir/html/$university/uims/uploads/
        cd $install_dir/html/$university/uims
        sed -i "s#/../vendor#$install_dir/uims/vendor#g" index.php
        sed -i "s#/../config#$install_dir/$university/uims/config#g" index.php
        sed -i "s#/../vendor#$install_dir/uims/vendor#g" jidebug.php
        sed -i "s#/../config#$install_dir/$university/uims/config#g" jidebug.php
        cd $install_dir/html/$university/uims/
## favicon
        cd $install_dir/html/$university/uims/

## logo

        # #setup www folder now
        mkdir -p $install_dir/$university/uims/config
        cp -R $install_dir/uims/config/* $install_dir/$university/uims/config
        cp $install_dir/uims/yii $install_dir/$university/uims/
        
        
        ## Configure db.php
        cd $install_dir/$university/uims/config
        sed -i "s/mysql:host=db_host/mysql:host=$rds_host/g" db.php
        sed -i "s/dbname=db_name/dbname=$db_genname/g" db.php
        sed -i "s/'username' => 'db_user'/'username' => '$db_username'/g" db.php
        sed -i "s/'password' => 'db_password'/'password' => '$db_password'/g" db.php
        cp db.php db_admission.php
        cp db.php db_nt.php
        cp db.php db_rec.php
        cp db.php db_student.php
        cp db.php db_uims.php


        ## Configure web.php
        sed -i "s#'basePath' => dirname(__DIR__)#'basePath' => '$install_dir/uims/'\n    'runtimePath' => __DIR__.\"/../runtime\"#" web.php
        # sed -i "s/'basePath' => dirname(__DIR__)/'basePath' => $install_dir/uims/" web.php
        sed -i "s/'dsn' => \"sentry_dsn\"/'dsn' => \"$sentry_dsn\"/" web.php
        sentry_tag=cu.${university}.uims
        sed -i "s/\"name\" => \"sentry_tag\"/\"name\" => \"$sentry_tag\"/" web.php
        sed -i "s/'hostname' => 'redis_host'/'hostname' => '$redis_host'/" web.php
        sed -i "s/'keyPrefix'=>'redis_key_prefix'/'keyPrefix'=>'$university'/" web.php
        sed -i "s/'cookieValidationKey' => 'cookie_val_key'/'cookieValidationKey' => '$(openssl rand -hex 20)'/" web.php


        ## Configure console.php
        sed -i "s#'basePath' => dirname(__DIR__)#'basePath' => '$install_dir/uims/'\n    'runtimePath' => __DIR__.\"/../runtime\"#" console.php



        # sed -i "s/redis_key_prefix/$university_$(openssl rand -hex 1)/" web.php
        mkdir -p $install_dir/$university/uims/runtime
        chown -R apache:apache $install_dir/$university/uims/runtime

# 'runtimePath' => __DIR__."/../runtime"
        ## Configure Database
        cd /var/www
        loc=$(pwd)
        echo -e "[client]\nuser = \"$admin_user\"\npassword = \"$admin_user_password\"\nhost = \"$rds_host\"\nport=3306" > $loc/config.cnf
        mysql --defaults-extra-file=$loc/config.cnf -e "CREATE DATABASE \`$db_genname\`CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql --defaults-extra-file=$loc/config.cnf -e "CREATE USER '$db_username'@'%' IDENTIFIED WITH mysql_native_password BY '$db_password';FLUSH PRIVILEGES;"
        mysql --defaults-extra-file=$loc/config.cnf -e "SELECT PLUGIN FROM \`mysql\`.\`user\` WHERE USER = '$db_username' AND HOST = '%';GRANT ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, DELETE, EVENT, EXECUTE, INDEX, INSERT, LOCK TABLES, REFERENCES, SELECT, SHOW VIEW, TRIGGER, UPDATE ON \`$db_genname\`.* TO '$db_username'@'%';"
        mysql --defaults-extra-file=$loc/config.cnf -e "SELECT PLUGIN FROM \`mysql\`.\`user\` WHERE USER = '$admin_user' AND HOST = '%';GRANT ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, DELETE, DROP, EVENT, EXECUTE, INDEX, INSERT, LOCK TABLES, REFERENCES, SELECT, SHOW VIEW, TRIGGER, UPDATE ON \`$db_genname\`.* TO '$admin_user'@'%' WITH GRANT OPTION;"


        
        
        
        
        
        
        ## Configure vhost. Keep this in last
        universityaccesslog=${university}_access_log
        universityerrorlog=${university}-error.log
        vhostfilename=${university}.conf
        cd /etc/httpd/conf.d
        cat >$vhostfilename<<EOF
        <VirtualHost *:80>
        ServerName $university.samarth.ac.in
        DocumentRoot $install_dir/html/$university/uims
        CustomLog /var/log/httpd/$universityaccesslog combined
        ErrorLog /var/log/httpd/$universityerrorlog
        <Directory $install_dir/html/$university/uims>
                Options FollowSymlinks
                DirectoryIndex index.html index.php
                AllowOverride All
                Require all granted
        </Directory>
        <LocationMatch "^(.*\.php)$">
                ProxyPass       unix:/var/run/php-fpm/www.sock|fcgi://localhost$install_dir/html/$university/uims/
                DirectoryIndex /index.php index.php
        </LocationMatch>
        </VirtualHost>
EOF










done
