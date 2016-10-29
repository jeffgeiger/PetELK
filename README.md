```
  ______           _______ _       _    _
 (_____ \     _   (_______) |     | |  / )
  _____) )___| |_  _____  | |     | | / /
 |  ____/ _  )  _)|  ___) | |     | |< <
 | |   ( (/ /| |__| |_____| |_____| | \ \
 |_|    \____)\___)_______)_______)_|  \_)

```

### Purpose  
PetELK is a quick way to build a working, reasonably tuned ELK stack for ad-hoc data analysis.  This can be done using vagrant, or the chef recipe can be applied to a physical system or VM.  This system is written for and tested on CentOS or RHEL 7.2.


### Directions

#### Vagrant    
**NOTE:**   
This Vagrantfile is configured to give the VM 9GB of RAM.  If your system can't do that adjust the `vm.memory` value, but be aware that performance will suffer.  
``` 
git clone https://github.com/jeffgeiger/PetELK.git
cd PetELK
vagrant up
```  
After the setup completes, your Kibana interface will be available at http://localhost:8000 with the credentials from below.

#### Physical/Virtual/Non-Vagrant  
**NOTE:**   
The system you run this on should have more than 4GB of RAM, with an OS (RHEL or CentOS 7) already installed.  
```
sudo rpm -Uvh https://packages.chef.io/stable/el/7/chef-12.14.89-1.el7.x86_64.rpm 
sudo yum install git -y
git clone https://github.com/jeffgeiger/PetELK.git
cd PetELK
sudo chef-client -z -r "recipe[PetELK]"
```  
After the setup completes, your Kibana interface will be available at http://{IP_OF_YOUR_BOX} with the credentials from below.


### Notes  
**LOGSTASH:** Logstash is configured to consume any properly formatted JSON file dropped into `/data/dumpfolder` with a `.json` extension.  You can look in `/var/log/logstash/` to see if logstash is barfing or whining about your data.
  
**CREDS:**  The default user for Kibana is `elastic` with a password of `changeme`.  Note that if you change this account, you'll also need to adjust the logstash config in `/etc/logstash/conf.d/files.conf`.
   
**PLUGINS:**  The beta version of the Elastic X-Pack plugin has been installed. This includes authentication, graph analysis, monitoring, and reporting. This is a commercial plugin with a 30 day trial license.

**EXAMPLE DATA:**  The examples folder contains some JSON bro data that you can gunzip and move to `/data/dumpfolder` to test things out.
