#!/bin/sh

# Configure an Alpine system to use cage to launch firefox at boot.
#
# Script notes:
#   - Change the urls to the tabs you want to open by default
#   - Keep the username "cage" this will be created and used for firefox.
#   - At bottom you enter what websites you want to block
#       (default is youtube.com and facebook.com)
#   - You can re-run this script at any time. It will delete and re-create the ffox
#   profile, so if you make your own customizations to it, you will lose them. 
#
# Alpine install notes:
# 1. boot USB
# 2. localhost login: root
# 3. setup-alpine
# 	1. keyboard
# 	2. hostname
# 	3. interface - eth0 and wlan0
# 	4. root password
# 	5. timezone
# 	6. (defaults for proxy and NTP)
# 	7. apk mirror: just hit enter will get default servers
# 	8. user (admin - will be used for ssh since root ssh disabled by default
#       we will later create user "cage" for firefox kiosk use, pick something else!
# 	9. default ssh server 
# 	10. disk and install - choose main disk
#        Default of "none" would be good for resetting at reboot but would need more
#        total RAM I am pretty sure)
# 		1. how to use disk? sys
#           system installed to disk - otherwise, can use "data" then apk cache and #           config of system on disk but it would only use RAM for the system
#           This would be nice in our case but not with 2gb total ram!
# 		2. erase disk and continue
# 	11. reboot

if [ $(id -u) -ne 0 ]
then
    echo
    echo "*** You must be root to run this script." >&2
    echo "Exiting...."
    sleep 5s
    exit 1
fi

USERNAME="cage"
URLS="'https://openmobile.us' 'https://wastalinux.org' 'https://desertblooms.net'"

apk update
apk upgrade

echo
echo "*** Setting up wayland base"
echo

setup-wayland-base
# note: installs and configures elogind and polkit-elogind

echo
echo "*** Installing packages"
echo

apk add nano firefox cage greetd font-misc-misc font-noto font-noto-ethiopic font-dejavu pipewire wireplumber

# note: Can use 'setup-apkcache' and enter 'none' to configure not to use cache but
# confusing to check if that is already set, and don't want to prompt user so just doing
# a manual removal for now.
echo
echo "*** Removing any apk cache"
echo
rm -rf /var/cache/apk/

USER_EXISTS=$(grep "^$USERNAME" /etc/passwd)
if [ -z "$USER_EXISTS" ]; then
    echo
    echo "Creating user: $USERNAME"
    echo
    
    # using "--comment" disables prompts for all the info like room number etc.
    adduser --disabled-password --gecos "" $USERNAME
fi

echo
echo "*** Stopping firefox and re-creating profile: $FFOX_PRO"
echo

killall firefox
FFOX_PRO=/home/$USERNAME/ffox-profile/
rm -rf /home/$USERNAME/.mozilla/
rm -rf /home/$USERNAME/.cache/mozilla/
rm -rf $FFOX_PRO
mkdir -p $FFOX_PRO

cat > $FFOX_PRO/user.js<< EOF
// do NOT prompt to resume from crash
user_pref("browser.sessionstore.resume_from_crash", false);

// do NOT restore closed tabs (will duplicate)
user_pref("browser.sessionstore.persist_closed_tabs_between_sessions", false);

// do NOT close firefox when last tab closed
user_pref("browser.tabs.closeWindowWithLastTab", false);

// attempt to NOT show "import bookarks" option
user_pref("browser.bookmarks.addedImportButton", false);

// disable quit shortcut - user can still choose "Quit" from Firefox Menu :-(
user_pref("browser.quitShortcut.disabled", true);

// Always show sidebar (still needed with revamp?)
user_pref("sidebar.visibility", "always-show");

// enable persistent sidebar
user_pref("sidebar.revamp", true);

// disable "ai chatbot"
user_pref("browser.ml.chat.enabled", false);

// default sidebar to vertical tabs
user_pref("sidebar.verticalTabs", true);

// remove other options from sidebar (history, etc)
user_pref("sidebar.main.tools", "");

// do NOT show "Firefox Privacy Notice" or other on "first run"
user_pref("datareporting.policy.firstRunURL", "");

// NOT ACTIVE enable use of userChrome.css for customizations
//user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// attempt to always show bookmarks toolbar
//user_pref("browser.toolbars.bookmarks.visibility", "always");
EOF

#mkdir -p $FFOX_CONFIG/$FFOX_PRO/chrome

#cat > $FFOX_CONFIG/$FFOX_PRO/chrome/userChrome.css<< EOF
#.titlebar-buttonbox-container {display:none !important;}
#EOF

echo
echo "*** Setting up cage launcher"
echo

cat > /home/$USERNAME/cage-launch.sh<< EOF
#!/bin/sh
/usr/libexec/pipewire-launcher &
cage -- firefox --profile "$FFOX_PRO" --kiosk $URLS
exit 0
EOF

echo
echo "*** Setting permissions"
echo

chown -R $USERNAME:$USERNAME /home/$USERNAME
chmod 755 /home/$USERNAME/cage-launch.sh

echo
echo "*** Configuring greetd cage launcher"
echo

sed -i -e "s@\(^command =\).*@\1 \"cage -s -- /home/$USERNAME/cage-launch.sh\"@" /etc/greetd/config.toml

sed -i -e "s@\(^user =\).*@\1 $USERNAME@" /etc/greetd/config.toml

rc-update add greetd
rc-service greetd start

echo
echo "*** Blocking some websites"
echo

# first delete then re-add (not combining so if delete not found will still re-add)
sed -i -e '\@youtube.com@d' /etc/hosts
sed -i -e '\@facebook.com@d' /etc/hosts
 
sed -i \
    -e '$a 127.0.0.1 www.youtube.com' \
    -e '$a 127.0.0.1 m.youtube.com' \
    -e '$a 127.0.0.1 www.facebook.com' \
    /etc/hosts

echo
echo "*** Done: reboot when ready"
echo

# reboot

exit 0
