<p align="left">
  <a href="https://github.com/vdarkobar/Home-Cloud#self-hosted-cloud">Home</a>
</p>  

  
# Nextcloud
self hosted open source cloud file storage and colaboration

  
Clone <a href="https://github.com/vdarkobar/DebianTemplate/blob/main/README.md#debian-template">Template</a>, SSH in using <a href="https://github.com/vdarkobar/Home-Cloud/blob/main/shared/Bastion.md#bastion">Bastion Server</a>  

  
### *Run this command*:
```
clear
sudo apt -y install git && \
RED='\033[0;31m'; NC='\033[0m'; echo -ne "${RED}Enter directory name: ${NC}"; read NAME; mkdir -p "$NAME"; \
cd "$NAME" && git clone https://github.com/vdarkobar/unbound.git . && \
chmod +x pihole-install.sh && \
chmod +x setup.sh && \
rm config-explained && \
rm README.md && \
rm steps.md && \
./setup.sh
```


<br><br>
*(steps used to configure <a href="https://github.com/vdarkobar/unbound/blob/main/steps.md">Unbound</a>)*
