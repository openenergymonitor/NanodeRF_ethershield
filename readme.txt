                               _      
                              | |     
 _ __   __ _   _ __   ___   __| | ___ 
| '_ \ / _` | | '_ \ / _ \ / _` |/ _ \
| | | | (_| | | | | | (_) | (_| |  __/
|_| |_|\__,_| |_| |_|\___/ \__,_|\___| RF
                                                  
networked application node
**************************

Builds on JeeLabs software 
-----------------------------------------------
Download the EtherCard, Ports and RF12 library here (insert into Arduino librarys folder):
http://jeelabs.net/projects/cafe/wiki/EtherCard
http://jeelabs.net/projects/cafe/wiki/Ports
http://jeelabs.net/projects/cafe/wiki/RF12
-----------------------------------------------
The is a colaboration between OpenEnergyMonitor and Nanode (Ken Boak and London Hackspace) 

This repo contains the firmware to allow a Nanode 5 equippted with a RFM12B break out board to received monitoring data from the emonTx and post the data online to emoncms. The Nanode also serves a local webpage with a copy of the last received data packet. 

On the Nanode 5 The SPI bus CS Chip Select or SS Slave Slect jumper must be set so that the Etherent chip (ENC28J60) is on digital 8 and the RFM12B is on digital 10 

Older version of the Nanode can be used with certian changes, see: http://openenergymonitor.org/emon/node/143

Links:
emonTx: openenergymonitor.org/emon/emontx
Nanode: http://wiki.hackspace.org.uk/wiki/Project:Nanode
 
