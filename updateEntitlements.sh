#!/bin/bash
#Original keychain_dumper by Patrick Toomey
#Scrpt by @ReverseThatApp and @vocaeq

KEYCHAIN_DUMPER_FOLDER=/usr/bin
if [ ! -d "$KEYCHAIN_DUMPER_FOLDER" ] ; then
  mkdir "$KEYCHAIN_DUMPER_FOLDER" ;
fi

# set -e ;

ENTITLEMENT_PATH=$KEYCHAIN_DUMPER_FOLDER/ent.xml
dbKeychainArray=()
declare -a invalidKeychainArray=("com.apple.bluetooth"
        "com.apple.cfnetwork"
        "com.apple.cloudd"
        "com.apple.continuity.encryption"
        "com.apple.continuity.unlock"
        "com.apple.icloud.searchpartyd"
        "com.apple.ind"
        "com.apple.mobilesafari"
        "com.apple.rapport"
        "com.apple.sbd"
        "com.apple.security.sos"
        "com.apple.siri.osprey"
        "com.apple.telephonyutilities.callservicesd"
        "ichat"
        "wifianalyticsd"
      )

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $ENTITLEMENT_PATH
echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" >> $ENTITLEMENT_PATH
echo "<plist version=\"1.0\">" >> ENTITLEMENT_PATH
echo "  <dict>" >> $ENTITLEMENT_PATH
echo "    <key>keychain-access-groups</key>" >> $ENTITLEMENT_PATH
echo "    <array>" >> $ENTITLEMENT_PATH

sqlite3 /var/Keychains/keychain-2.db "SELECT DISTINCT agrp FROM genp" > ./allgroups.txt
sqlite3 /var/Keychains/keychain-2.db "SELECT DISTINCT agrp FROM cert" >> ./allgroups.txt
sqlite3 /var/Keychains/keychain-2.db "SELECT DISTINCT agrp FROM inet" >> ./allgroups.txt
sqlite3 /var/Keychains/keychain-2.db "SELECT DISTINCT agrp FROM keys" >> ./allgroups.txt

while IFS= read -r line; do
  dbKeychainArray+=("$line")
    if [[ ! " ${invalidKeychainArray[@]} " =~ " ${line} " ]]; then
      echo "      <string>${line}</string>">> $ENTITLEMENT_PATH
  else
    echo "Skipping ${line}"
  fi
done < ./allgroups.txt

# cat ./allgroups.txt | sed 's/.*/\ \ \ \ \ \ \ \ \<string\>&\<\/string\>/' >> $ENTITLEMENT_PATH
rm ./allgroups.txt

echo "    </array>">> $ENTITLEMENT_PATH
echo "    <key>platform-application</key> <true/>">> $ENTITLEMENT_PATH
echo "    <key>com.apple.private.security.no-container</key>  <true/>">> $ENTITLEMENT_PATH
echo "  </dict>">> $ENTITLEMENT_PATH
echo "</plist>">> $ENTITLEMENT_PATH

cd $KEYCHAIN_DUMPER_FOLDER
ldid -Sent.xml keychain_dumper
rm ent.xml
echo "Entitlements updated"
