                               _      
                              | |     
 _ __   __ _   _ __   ___   __| | ___ 
| '_ \ / _` | | '_ \ / _ \ / _` |/ _ \
| | | | (_| | | | | | (_) | (_| |  __/
|_| |_|\__,_| |_| |_|\___/ \__,_|\___| RF
                             _   _          
   ___ _ __ ___   ___  _ __ | |_) | __ _ ___  ___ 
  / _ \ '_ ` _ \ / _ \| '_ \|  _ < / _` / __|/ _ \
 |  __/ | | | | | (_) | | | | |_) | (_| \__ \  __/
  \___|_| |_| |_|\___/|_| |_|____/ \__,_|___/\___|                                    

                                                  
                                                  
emonBase (emonTx base station) to post data to emoncms or Pachube 
**************************

Builds on JeeLabs and EtherCard software. Thanks to JCW and Andrewd Lindsay
-----------------------------------------------
Download the EtherSield, Ports and RF12 library here (insert into Arduino librarys folder):
https://github.com/thiseldo/EtherShield
http://jeelabs.net/projects/cafe/wiki/Ports
http://jeelabs.net/projects/cafe/wiki/RF12
-----------------------------------------------
The is a colaboration between OpenEnergyMonitor.org and Nanode.eu (Ken Boak and London Hackspace) 

This repo contains the firmware to allow a Nanode 5 equippted with a RFM12B breakout board to received monitoring data from the emonTx and post the data online to emoncms. The Nanode also serves a local webpage with a copy of the last received data packet. 

On the Nanode 5 SPI bus CS Chip Select/ SS Slave Select is digital 8 for the Etherent chip (ENC28J60) and digital 10 for the RFM12B.

Older version of the Nanode can be used with certian changes, see: http://openenergymonitor.org/emon/node/143

Links:
emonTx: openenergymonitor.org/emon/emontx
Nanode: http://wiki.hackspace.org.uk/wiki/Project:Nanode
 
