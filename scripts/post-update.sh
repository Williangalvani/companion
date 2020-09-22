#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo 'STARTING POST UPDATE'
echo $(printenv)

# Bugfix for revert on first update. 0.0.7 had a bug in update.sh where the companion directory was not copied correctly (no -r option)
# Do it the right way here so we can revert if
cd $HOME/companion
WAS_0_0_7=$(git rev-list --count revert-point...0.0.7)
if [ $WAS_0_0_7 == 0 ]; then
    echo '0.0.7 update, repairing fall-back...'
    cp -r $HOME/companion $HOME/.companion
    cd $HOME/.companion
    git reset --hard 0.0.7
fi

cd $HOME/companion/br-webui

if ! npm list nodegit 2>&1 | grep -q nodegit@0.18.3; then
    echo 'Fetching nodegit packages for raspberry pi...'
    wget --timeout=15 --tries=2 https://s3.amazonaws.com/downloads.bluerobotics.com/Pi/dependencies/nodegit/nodegit_required_modules.zip -O /tmp/nodegit_required_modules.zip
    if [ $? -ne 0 ] # If "wget" failed:
    then
        echo 'Failed to retrieve nodegit packages; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Extracting prebuilt packages...'
    unzip -q /tmp/nodegit_required_modules.zip -d ~/companion/br-webui/node_modules/
fi

# TODO prune unused npm modules here

echo 'run npm install'
npm install
if [ $? -ne 0 ] # If "npm install" failed:
then
    echo 'Failed to install required npm modules; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
    sleep 0.1
    sudo reboot
fi

cd $HOME/companion

echo 'Updating submodules...'
git submodule init && git submodule sync
if [ $? -ne 0 ] # If either "git submodule" failed:
then
    echo 'Failed to update submodules; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
    sleep 0.1
    sudo reboot
fi

# https://git-scm.com/docs/git-submodule#git-submodule-status--cached--recursive--ltpathgt82308203

echo 'Checking mavlink status...'
MAVLINK_STATUS=$(git submodule status | grep mavlink | head -c 1)
if [[ ! -z $MAVLINK_STATUS && ($MAVLINK_STATUS == '+' || $MAVLINK_STATUS == '-') ]]; then
    # Remove old mavlink directory if it exists
    [ -d ~/mavlink ] && sudo rm -rf ~/mavlink
    echo 'mavlink needs update.'
    git submodule update --recursive --init -f submodules/mavlink
    if [ $? -ne 0 ] # If mavlink submodule update failed:
    then
        echo 'Failed to update mavlink submodule; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Installing mavlink...'
    cd $HOME/companion/submodules/mavlink/pymavlink
    sudo python setup.py build install
    if [ $? -ne 0 ] # If mavlink installation update failed:
    then
        echo 'Failed to install mavlink; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
else
    echo 'mavlink is up to date.'
fi

cd $HOME/companion

echo 'Checking MAVProxy status...'
MAVPROXY_STATUS=$(git submodule status | grep MAVProxy | head -c 1)
if [[ ! -z $MAVPROXY_STATUS && ($MAVPROXY_STATUS == '+' || $MAVPROXY_STATUS == '-') ]]; then
    echo 'MAVProxy needs update.'
    git submodule update --recursive -f submodules/MAVProxy
    if [ $? -ne 0 ] # If MAVProxy submodule update failed:
    then
        echo 'Failed to update MAVProxy submodule; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    echo 'Installing MAVProxy...'
    cd $HOME/companion/submodules/MAVProxy
    sudo python setup.py build install
    if [ $? -ne 0 ] # If MAVProxy installation update failed:
    then
        echo 'Failed to install MAVProxy; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
else
    echo 'MAVProxy is up to date.'
fi

echo 'checking for github in known_hosts'

# Check for github key in known_hosts
if ! ssh-keygen -H -F github.com; then
    mkdir ~/.ssh

    # Get gihub public key
    ssh-keyscan -t rsa -H github.com > /tmp/githost

    # Verify fingerprint
    if ssh-keygen -lf /tmp/githost | grep -q 16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48; then
        # Add to known_hosts
        cat /tmp/githost >> ~/.ssh/known_hosts
    fi
fi

# install pynmea2 if neccessary
if pip list | grep pynmea2; then
    echo 'pynmea2 already installed'
else
    echo 'installing pynmea2...'
    sudo pip install pynmea2
    if [ $? -ne 0 ] # If "pip install pynmea2" failed:
    then
        echo 'Failed to install pynmea2; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
fi

# install grequests if neccessary
if pip list | grep grequests; then
    echo 'grequests already installed'
else
    echo 'Fetching grequests packages for raspberry pi...'
    wget --timeout=15 --tries=2 https://s3.amazonaws.com/downloads.bluerobotics.com/Pi/dependencies/grequests/grequests.zip -O /tmp/grequests.zip
    if [ $? -ne 0 ] # If "wget" failed:
    then
        echo 'Failed to retrieve grequests packages; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
    echo 'Extracting prebuilt packages...'
    sudo unzip -q -o /tmp/grequests.zip -d /
    echo 'installing grequests...'
    sudo pip install grequests
    if [ $? -ne 0 ] # If "pip install grequests" failed:
    then
        echo 'Failed to install grequests; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi
fi

# copy default parameters if neccessary
cd $HOME/companion/params

for default_param_file in *; do
    if [[ $default_param_file == *".param.default" ]]; then
        param_file="$HOME/"$(echo $default_param_file | sed "s/.default//")
        if [ ! -e "$param_file" ]; then
            cp $default_param_file $param_file
        fi
    fi
done

# change the pi user password to 'bluerobotics' instead of the default 'raspberry'
PRE_0_0_8=$(( git rev-list --count --left-right 0.0.8...revert-point || echo 0 ) | cut -f1)
if (( $PRE_0_0_8 > 0 )); then
    echo "changing default password to 'companion'..."
    echo "pi:companion" | sudo chpasswd
fi

# We need to load bcm v4l2 driver in case Raspberry Pi camera is in use
PRE_0_0_11=$(( git rev-list --count --left-right 0.0.11...revert-point || echo 0 ) | cut -f1)
if (( $PRE_0_0_11 > 0 )); then
    echo "restarting video stream"
    ~/companion/scripts/start_video.sh $(cat ~/companion/params/vidformat.param.default)
fi

# add local repo as a remote so it will show up in webui
cd ~/companion
if ! git remote | grep -q local; then
    echo 'Adding local reference'
    git remote add local ~/companion
fi

# Check pre-0.0.16 for networking dependencies
PRE_0_0_16=$(( git rev-list --count --left-right 0.0.16...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_16 > 0 )); then
    echo "Installing isc-dhcp-server"
    sudo apt-get update --yes
    sudo apt-get install isc-dhcp-server=4.3.* --yes

    if [ $? -ne 0 ] # If install failed:
    then
        echo 'Failed to install isc-dhcp-server; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    #Copy network configuration files from Companion directory to respective configuration directories
    sudo cp /home/pi/companion/params/interfaces-eth0 /etc/network/interfaces.d/

    #Source configuration for dhcp server in the default configuration files
    sudo sed -i '\%/home/pi/companion/%d' /etc/dhcp/dhcpd.conf
    sudo sh -c "echo 'include \"/home/pi/companion/params/dhcpd-server.conf\";' >> /etc/dhcp/dhcpd.conf"

    sudo sed -i '\%/home/pi/companion/%d' /etc/default/isc-dhcp-server
    sudo sh -c "echo '. /home/pi/companion/params/isc-dhcp.conf' >> /etc/default/isc-dhcp-server"

    #Copy default network configuration to user folder
    cp /home/pi/companion/params/network.conf.default /home/pi/network.conf
    echo "isc-dhcp-server installed"

    #Delete ip address if present from /boot/cmdline.txt
    # e.g. sed command removes any ip address with any combination of digits [0-9] between decimal points
    sudo sed -i -e 's/\s*ip=[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*//' /boot/cmdline.txt

    echo "alias stopscreens=\"screen -ls | grep Detached | cut -d. -f1 | awk '{print \$1}' | xargs kill\"" >> ~/.bash_aliases

    echo 192.168.2.2 > /home/pi/static-ip.conf

    # remove any line containing 'enable_uart=' from /boot/config.txt
    sudo sed -i '/enable_uart=/d' /boot/config.txt

    # append 'enable_uart=1' line to /boot/config.txt
    echo "enable_uart=1" | sudo tee -a /boot/config.txt

    # override start timeout for networking service to prevent hang at boot in certain misconfiguraitons
    sudo mkdir -p /etc/systemd/system/networking.service.d
    sudo sh -c "echo '[Service]\nTimeoutStartSec=10' > /etc/systemd/system/networking.service.d/timeout.conf"
fi

# Check pre-0.0.17 to copy udev files
PRE_0_0_17=$(( git rev-list --count --left-right 0.0.17...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_17 > 0 )); then
    sudo pip install bluerobotics-ping==0.0.7

    # If "pip install bluerobotics-ping" failed:
    if [ $? -ne 0 ]; then
        echo 'Failed to install bluerobotics-ping; Aborting update'
        echo 'Rebooting to repair installation, this will take a few minutes'
        echo 'Please DO NOT REMOVE POWER FROM THE ROV! (until QGC makes a connection again)'
        sleep 0.1
        sudo reboot
    fi

    sudo cp $HOME/companion/params/100.autopilot.rules /etc/udev/rules.d/
fi

# Check pre-0.0.18 to update bluerobotics-ping
PRE_0_0_18=$(( git rev-list --count --left-right 0.0.18...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_18 > 0 )); then
    sudo pip install bluerobotics-ping==0.0.9 --upgrade --force-reinstall
fi

# Check pre-0.0.19 to update bluerobotics-ping and navigator setup
PRE_0_0_19=$(( git rev-list --count --left-right 0.0.19...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_19 > 0 )); then
    # Use the last version of bluerobotics-ping
    sudo pip install bluerobotics-ping==0.0.10 --upgrade --force-reinstall

    ## Navigator
    # Remove any configuration related to i2c and spi/spi1 and do the necessary changes for navigator
    for STRING in "dtparam=i2c_arm=" "dtparam=spi=" "dtoverlay=spi1" "dtoverlay=uart1"; do
        sudo sed -i "/$STRING/d" /boot/config.txt
    done
    for STRING in "dtparam=i2c_arm=on" "dtparam=spi=on" "dtoverlay=spi1-3cs" "dtoverlay=uart1"; do
        echo "$STRING" | sudo tee -a /boot/config.txt
    done

    # Remove any configuration or commented part related to the i2c drive
    for STRING in "i2c-dev" "i2c-bcm2708"; do
        sudo sed -i "/$STRING/d" /etc/modules
        echo "$STRING" | sudo tee -a /etc/modules
    done

    # Remove any console serial configuration
    sudo sed -e 's/console=serial[0-9],[0-9]*\ //' -i /boot/cmdline.txt

    # Install i2c tools
    sudo apt update --yes
    sudo apt install i2c-tools --yes

    # Install socat to create bind between /dev/navigator and /dev/autopilot
    sudo apt install socat --yes

    # This versions updates mavproxy default parameters
    # The user should apply the default parameters if he wishs to use all features available
fi

# Check pre-0.0.21 to merge our updated (0.0.17...0.0.20) default mavproxy configuration
# with any existing user configuration
PRE_0_0_21=$(( git rev-list --count --left-right 0.0.21...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_21 > 0 )); then
    # reconfigure only if a user configuration exists in the home directory
    USER_MAVPROXY_PARAMS=$HOME/mavproxy.param
    if [ -e $USER_MAVPROXY_PARAMS ]; then
        # delete any streamrate line if it already exists
        sed -i '/--streamrate*/d' $USER_MAVPROXY_PARAMS
        # append the streamrate line we require
        sed -i '$ a --streamrate 10' $USER_MAVPROXY_PARAMS

        # delete port for mavlink 2 rest server if it exists
        # append port for mavlink2rest server, ensuring it occurs only once
        sed -i '/--out udpout:localhost:9002/d' $USER_MAVPROXY_PARAMS
        sed -i '$ a --out udpout:localhost:9002' $USER_MAVPROXY_PARAMS

        # delete port for ping-viewer if it exists
        # append port for ping-viewer, ensuring it occurs only once
        sed -i '/--out udpin:0.0.0.0:14660/d' $USER_MAVPROXY_PARAMS
        sed -i '$ a --out udpin:0.0.0.0:14660' $USER_MAVPROXY_PARAMS
    fi
fi

# Check pre-0.0.22 to install network service
PRE_0_0_22=$(( git rev-list --count --left-right 0.0.22...revert-point || echo 0 ) | cut -f1)

if (( $PRE_0_0_22 > 0 )); then
    sudo apt install -y python3-pip
    sudo python3 $HOME/companion/services/network/setup.py install
fi


# DVL stuff, unguarded because there is no tag
sudo apt install -y python3-pip
sudo python3 $HOME/companion/services/network/setup.py install
sudo python3 $HOME/companion/services/waterlinked/dvl-a50/setup.py install


echo 'Update Complete, the system will reboot now.'
echo 'Wait for 30 seconds and refresh the page.'

sleep 0.1

sudo -H -u pi echo 'quit webui' >> $HOME/.update_log
screen -X -S webui quit

sudo -H -u pi echo 'restart webui' >> $HOME/.update_log
sudo -H -u pi screen -dm -S webui $HOME/companion/scripts/start_webui.sh

sudo -H -u pi echo 'removing lock' >> $HOME/.update_log
rm -f $HOME/.updating

# Reboot the system now and calling shutdown as a detached background subshell process
sudo shutdown -r now &
