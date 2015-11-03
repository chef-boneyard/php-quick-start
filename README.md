### DEPRECATED
**This guide repository has not been updated and is no longer correct for current Chef releases. It should only be used for historical context at this point.**

This guide describes how to build a PHP application stack using Chef cookbooks available from the [Cookbooks Community Site](http://cookbooks.opscode.com) and Opscode's Hosted Chef. It assumes you followed the [Getting Started Guide](http://help.opscode.com/faqs/start/how-to-get-started) and have Chef installed. 

*This guide uses Ubuntu 10.04 on Amazon AWS EC2 with Chef 0.10.0.*

***Note:** At this time, the steps described above have only been tested on the identified platform(s).  Opscode has not researched and does not support alternative steps that may lead to successful completion on other platforms.  Platform(s) supported by this guide may change over time, so please do check back for updates.  If you'd like to undertake this guide on an alternate platform, you may desire to turn to open source community resources for support assistance.*

You can watch a short screencast of this guide [here](http://blip.tv/opscode/build-a-mediawiki-lamp-stack-with-chef-5211811):

<embed src="http://blip.tv/play/hMAggr6OBwA" type="application/x-shockwave-flash" width="600" height="480" wmode="transparent" allowscriptaccess="always" allowfullscreen="true" ></embed>


At the end of this guide, you'll have four total Ubuntu 10.04 systems running in Amazon EC2.

- 1 haproxy load balancer.
- 2 Apache2 web servers running `mod_php`.
- 1 MySQL database server.

The PHP application used in this guide is [MediaWiki 1.18alpha](http://mediawiki.org/), which powers everyone's favorite encyclopedia [Wikipedia](http://wikipedia.com)

We're going to reuse a number of cookbooks from the [Cookbooks Community Site](http://cookbooks.opscode.com) to build the environment. For example, the source code lives in **git**, so that cookbook will ensure Git is available. The load balancer is **haproxy** because it is very simple to deploy and configure, and we use a recipe that automatically discovers the PHP application systems. The heavy lifting is handled by recipes in the **application** and **database** cookbooks.

The **application** cookbook will perform the following steps:

* install required packages and pears for the project
* set up the deployment scaffolding
* creates LocalSettings.php file with the database connection information if required
* performs a revision-based deploy
* install Apache2 and mod_php
* create an application specific virtual host configuration file.

We are also following the recommended pattern of creating a cookbook named after the application that is being deployed which contains application specific setup and configurations. In this case, the **mediawiki** cookbook contains a recipe that will be used for bootstrapping our database.  It also contains the template that will be used to render our `LocalSettings.php` file.

If you don't already have an account with Amazon AWS, go to [Amazon Web Sevices](http://aws.amazon.com/) and click "Sign up". You'll need the access and secret access key credentials from the sign-up later.

Environment Setup
----

First, let's configure the local workstation.

### Shell Environment

Obtain the repository used for this guide. It contains all the components required. Use git:

    git clone git://github.com/opscode/php-quick-start.git

### Chef and Knife

*Ubuntu/Debian users*: Install XML2 and XLST development headers on your system:

    sudo apt-get install libxml2-dev libxslt-dev

*All Users*: You'll need some additional gems for Knife to launch instances in Amazon EC2:

    sudo gem install knife-ec2

As part of the [Getting Started Guide](help.opscode.com/faqs/start/how-to-get-started), you cloned a chef-repo and copied the Knife configuration file (knife.rb), validation certificate (ORGNAME-validator.pem) and user certificate (USERNAME.pem) to **~/chef-repo/.chef/**. Copy these files to the new php-quick-start repository. You can also re-download the Knife configuration file for your [Organization from the Management Console](http://help.opscode.com/faqs/start/user-environment).

    mkdir ~/php-quick-start/.chef
    cp ~/chef-repo/.chef/knife.rb ~/php-quick-start/.chef
    cp ~/chef-repo/.chef/USERNAME.pem ~/php-quick-start/.chef
    cp ~/chef-repo/.chef/ORGNAME-validator.pem ~/php-quick-start/.chef

Add the Amazon AWS credentials to the Knife configuration file.

    vi ~/php-quick-start/.chef/knife.rb

Add the following two lines to the end:

    knife[:aws_access_key_id] = "replace with the Amazon Access Key ID"
    knife[:aws_secret_access_key] =  "replace with the Amazon Secret Access Key ID"

Once the php-quick-start and knife configuration is in place, we'll work from this directory.

    cd php-quick-start

### Amazon AWS EC2

In addition to the credentials, two additional things need to be configured in the AWS account.

Configure the default [security group](http://docs.amazonwebservices.com/AWSEC2/latest/DeveloperGuide/index.html?using-network-security.html) to allow incoming connections for the following ports.

* 22 - ssh
* 80 - haproxy load balancer
* 22002 - haproxy administrative interface
* 8080 - apache2 web servers running mod_php

Add these to the default security group for the account using the AWS Console.

1. Sign into the [Amazon AWS Console](https://console.aws.amazon.com/s3/home).
2. Click on the "Amazon EC2" tab at the top.
3. Click on "Security Groups" in the left sidebar of the AWS Console.
4. Select the "Default" group in the main pane.
5. Enter the values shown for each of the ports required. Use "Custom" in the drop-down for 22002 and 8080.
![aws-management-console](http://img.skitch.com/20101104-qyy612rgcrr9k24ca29qarehc9.jpg)

Create an [SSH Key Pair](http://docs.amazonwebservices.com/AWSEC2/latest/DeveloperGuide/index.html?using-credentials.html#using-credentials-keypair) and save the private key in **~/.ssh**.

1. In the AWS Console, click on "Key Pairs" in the left sidebar.
2. Click on "Create Keypair" at the top of the main pane.
3. Give the keypair a name like "php-quick-start".
4. The keypair will be downloaded automatically by the browser and saved to the default Downloads location.
5. Move the php-quick-start.pem file from the default Downloads location to **~/.ssh** and change permissions so that only you can read the file.  For example,

    mv ~/Downloads/php-quick-start.pem ~/.ssh  
    chmod 600 ~/.ssh/php-quick-start.pem

Acquire Cookbooks
----

The php-quick-start has all the cookbooks we need for this guide. They were downloaded along with their dependencies from the cookbooks site using Knife. These are in the **cookbooks/** directory.

    apt
    git
    application
    database
    haproxy

A single new non-community cookbook was also created for this quick-start. This mediawiki cookbook contains a recipe that is used to bootstrap our database and create the initial superuser. This follows the recommended pattern of creating a cookbook named after the application which contains application specific setup and configurations.

    mediawiki

Upload all the cookbooks to the Hosted Chef server.

    knife cookbook upload -a

Server Roles
------------

All the required roles have been created in the php-quick-start repository. They are in the **roles/** directory.

    base.rb
    mediawiki_database_master.rb
    mediawiki.rb
    mediawiki_load_balancer.rb

Upload all the roles to the Hosted Chef server.

    rake roles

Data Bag Item
----

The php-quick-start repository contains a data bag item that has all the information required to deploy and configure the MediaWiki application from source using the recipes in the **application** and **database** cookbooks.

The data bag name is **apps** and the item name is **mediawiki**. Upload this to the Hosted Chef server.

    knife data bag create apps
    knife data bag from file apps mediawiki.json

Decision Time
====

It is time for you to decide whether you want a single instance running MediaWiki, or a few instances as a small infrastructure.

In either case, we're going to use m1.small instances with the 32 bit Ubuntu 10.04 image provided [by Canonical](http://uec-images.ubuntu.com/releases/10.04/release-20101228/). The identifier is **ami-7000f019** for the AMI in us-east-1 with instance storage that we will use in this guide.  We'll show you the **knife ec2 server create** sub-command to launch instances.

This command will:

* Launch a server on EC2.
* Connect it to the Hosted Chef server.
* Configure the system with Chef.

See the appropriate section below for instruction on launching a single instance, or launching the multi-system infrastructure.

Launch Single Instance
----

Launch the entire stack on a single instance.

    knife ec2 server create -G default -I ami-7000f019 -f m1.small \
      -S php-quick-start -i ~/.ssh/php-quick-start.pem -x ubuntu \
      -r 'role[base],role[mediawiki_database_master],role[mediawiki],recipe[mediawiki::db_bootstrap],role[mediawiki_load_balancer]'

Once complete, the instance will be running MySQL and MediaWiki under Apache2 + mod_php. With only one system, a load balancer is unnecessary.

Launch Multi-instance Infrastructure
----

We will launch one database server, two application servers and one load balancer. One of the application server instances will include the role for running migrations as discussed before.

First, launch the database instance.

    knife ec2 server create -G default -I ami-7000f019 -f m1.small \
      -S php-quick-start -i ~/.ssh/php-quick-start.pem -x ubuntu \
      -r 'role[base],role[mediawiki_database_master]'

Once the database master is up, launch one node that will create the database schema and set up the database with default data.

    knife ec2 server create -G default -I ami-7000f019 -f m1.small \
      -S php-quick-start -i ~/.ssh/php-quick-start.pem -x ubuntu \
      -r 'role[base],role[mediawiki],recipe[mediawiki::db_bootstrap]' 

Launch the second application instance w/o the mediawiki::db_bootstrap recipe.

    knife ec2 server create -G default -I ami-7000f019 -f m1.small \
      -S php-quick-start -i ~/.ssh/php-quick-start.pem -x ubuntu \
      -r 'role[base],role[mediawiki]' 

Once the second application instance is up, launch the load balancer.

    knife ec2 server create -G default -I ami-7000f019 -f m1.small \
      -S php-quick-start -i ~/.ssh/php-quick-start.pem -x ubuntu \
      -r 'role[base],role[mediawiki_load_balancer]'

Once complete, we'll have four instances running in EC2 with MySQL, MediaWiki and haproxy up and available to serve traffic.

Verification
----

Knife will output the fully qualified domain name of the instance when the commands complete. Navigate to the public fully qualified domain name on port 80.

    http://ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com/

The login is admin and the password is mediawiki.

You can access the haproxy admin interface at:

    http://ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com:22002/

Appendix
----

### Database Passwords

The data bag item for MediaWiki contains default passwords that should certainly be changed to something stronger.

The passwords in the MediaWiki Data Bag Item are set to the values show below:

    "mysql_root_password": {
      "_default": "mysql_root"
    },
    "mysql_debian_password": {
      "_default": "mysql_debian"
    },
    "mysql_repl_password": {
      "_default": "mysql_repl"
    },
    
To change the password to something stronger, modify **mysql_root**, **mysql_debian**, **mysql_repl** values. Something like the following secure passwords:

    vi data_bags/apps/mediawiki.json
    "mysql_root_password": {
      "_default": "super_s3cur3_r00t_pw"
    },
    "mysql_debian_password": {
      "_default": "super_s3cur3_d3b1@n_pw"
    },
    "mysql_repl_password": {
      "_default": "super_s3cur3_r3pl_pw"
    },

Once the entries are modified, simply load the data bag item from the json file:

    knife data bag from file apps mediawiki.json

### Non-EC2 Systems

For people not using Amazon EC2, other Cloud computing providers can be used. Supported by knife and fog as of this revision:

* Rackspace Cloud

See the [launch cloud instances page](http://wiki.opscode.com/display/chef/Launch+Cloud+Instances+with+Knife) on the Chef wiki for more information about using Knife to launch these instance types.

For people not using cloud at all, but have their own infrastructure and hardware, use the [bootstrap](http://wiki.opscode.com/display/chef/Knife+Bootstrap) knife command. Note that the run-list specification is slightly different. For the first example of the single instance:

    knife bootstrap IPADDRESS \
    -r 'role[base],role[mediawiki_database_master],role[mediawiki],recipe[mediawiki::db_bootstrap],role[mediawiki_load_balancer]'

See the contextual help for knife bootstrap on the additional options to set for SSH.

    knife bootstrap --help

### A Note about EC2 Instances

We used m1.small instances. This is a low performance instance size in EC2 and just fine for testing. Visit the Amazon AWS documentation to [learn more about instance sizes](http://aws.amazon.com/ec2/instance-types/).
