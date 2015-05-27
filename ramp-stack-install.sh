#!/bin/bash
#Call StackScript Library
source <ssinclude StackScriptID="1">

# <UDF name="db_password" Label="MySQL root Password" />
# <UDF name="db_name" Label="Create Database" default="" example="Optionally create this database" />
# <UDF name="db_user" Label="Create MySQL User" default="" example="Optionally create this user" />
# <UDF name="db_user_password" Label="MySQL User's Password" default="" example="User's password" />
# <UDF name="php_install" label="Install PHP" oneOf="yes,no" />
# <UDF name="ruby_version" label="Choose Ruby Version" oneOf="ruby-1.9.1-p376,ruby-1.9.0-0,ruby-1.9.0-1" example="These are downloaded from ftp://ftp.ruby-lang.org" />
# <UDF name="gems_to_install1" label="Gems to install" manyOf="rails,mysql,passenger,sqlite3-ruby,rspec,rcov,capistrano" default="rails,mysql,passenger" example="Each selected gem will be installed." />
# <UDF name="gems_to_install2" label="More gems to install" default="" example="Comma separated inputs to gem install. Example: rails,nifty-generators,formtastic,... Add the -v if you need a specific version." />

logfile="/root/log.txt"
rubyscript="/root/ruby_script_to_run.rb" 
# This script is generated and run after gem is installed to
# install the list of gems given by the stack script."

export logfile
export gems_to_install1="$GEMS_TO_INSTALL1"
export gems_to_install2="$GEMS_TO_INSTALL2"
# exported to be available in ruby_script_to_run.rb

system_update
echo "System Updated" >> $logfile
postfix_install_loopback_only
echo "postfix_install_loopback_only" >> $logfile
mysql_install "$DB_PASSWORD" && mysql_tune 40
echo "Mysql installed" >> $logfile
mysql_create_database "$DB_PASSWORD" "$DB_NAME"
mysql_create_user "$DB_PASSWORD" "$DB_USER" "$DB_USER_PASSWORD"
mysql_grant_user "$DB_PASSWORD" "$DB_USER" "$DB_NAME"

if [[ $PHP_INSTALL == yes ]]
    then
      php_install_with_apache && php_tune
        echo "Php installed" >> $logfile
        fi

        apache_install && apache_tune 40 && apache_virtualhost_from_rdns
        echo "apache installed" >> $logfile
        goodstuff
        echo "goodstuff installed" >> $logfile

#installing ruby
apt-get -y install build-essential libssl-dev libreadline5-dev zlib1g-dev
echo "libs for ruby installed" >> $logfile
echo "$RUBY_VERSION.tar.gz" >> $logfile
echo "$RUBY_VERSION" >> $logfile

echo "" >> $logfile
if [[ $RUBY_VERSION == ruby\-1\.9* ]]
    then
        echo "Downloadin: (from calling wget ftp://ftp.ruby-lang.org/pub/ruby/1.9/$RUBY_VERSION.tar.gz)" >> $logfile
        echo "" >> $logfile
            wget ftp://ftp.ruby-lang.org/pub/ruby/1.9/$RUBY_VERSION.tar.gz  >> $logfile
            else
                    echo "Downloadin: (from calling wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/$RUBY_VERSION.tar.gz)" >> $logfile
                    echo "" >> $logfile
                        wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/$RUBY_VERSION.tar.gz  >> $logfile
                        fi

                        echo ""
                        echo "tar output:"
                        tar xzf $RUBY_VERSION.tar.gz >> $logfile
                        rm $RUBY_VERSION.tar.gz
                        cd $RUBY_VERSION

                        echo ""
                        echo "current directory:"
                        pwd >> $logfile

                        echo "" >> $logfile
                        echo "Ruby Configuration output: (from calling ./configure --disable-ucontext --enable-pthread)" >> $logfile
                        echo "" >> $logfile
                        ./configure --disable-ucontext --enable-pthread >> $logfile

                        echo "" >> $logfile
                        echo "Ruby make output: (from calling make)" >> $logfile
                        echo "" >> $logfile
                        make >> $logfile

                        echo "" >> $logfile
                        echo "Ruby make install output: (from calling make install)" >> $logfile
                        echo "" >> $logfile
                        make install >> $logfile
                        cd /
                        rm -rf $RUBY_VERSION

                        echo "" >> $logfile
                        echo "Downloading Ruby Gems with wget http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz" >> $logfile
                        echo "" >> $logfile
                        wget http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz >> $logfile

                        echo ""
                        echo "tar output:"
                        tar xzvf rubygems-1.3.6.tgz  >> $logfile
                        rm rubygems-1.3.6.tgz

                        echo ""
                        echo "rubygems setup:"
                        cd rubygems-1.3.6
                        ruby setup.rb >> $logfile
                        cd /
                        rm -rf rubygems-1.3.6

                        echo ""
                        echo "gem update --system:"
                        gem update --system >> $logfile

# echo the ruby code to a file to be run
echo "
    ##### Ruby Code Starts Here #####

        gems_to_install1 = ENV['gems_to_install1']
            gems_to_install2 = ENV['gems_to_install2']
                
                    puts gems_to_install1
                        puts gems_to_install2
                            
                                gems_to_install1.split(',').each do |gem_name|
                                      \`gem install #{gem_name} >> $logfile\`
                                          end
                                              
                                                  gems_to_install2.split(',').each do |gem_name|
                                                        \`gem install #{gem_name} >> $logfile\`
                                                            end

                                                                ##### Ruby Code Ends Here #####" >> $rubyscript

                                                                ruby $rubyscript >> $logfile

                                                                restartServices
                                                                echo "StackScript Finished!" >> $logfile
