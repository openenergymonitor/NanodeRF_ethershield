/*                          _                                                      _      
                           | |                                                    | |     
  ___ _ __ ___   ___  _ __ | |__   __ _ ___  ___       _ __   __ _ _ __   ___   __| | ___ 
 / _ \ '_ ` _ \ / _ \| '_ \| '_ \ / _` / __|/ _ \     | '_ \ / _` | '_ \ / _ \ / _` |/ _ \
|  __/ | | | | | (_) | | | | |_) | (_| \__ \  __/  _  | | | | (_| | | | | (_) | (_| |  __/
 \___|_| |_| |_|\___/|_| |_|_.__/ \__,_|___/\___| (_) |_| |_|\__,_|_| |_|\___/ \__,_|\___|
                                                                                          
*/
//--------------------------------------------------------------------------------------
// Relay's data recieved by emontx up to pachube
// Minimal CT and supply voltage only version

// Uses JeeLabs RF12 library http://jeelabs.org/2009/02/10/rfm12b-library-for-arduino/
// Uses Andrew Lindsay's EtherShield library - using DHCP

// By Glyn Hudson and Trystan Lea
// openenergymonitor.org
// GNU GPL V3

// Last update: 12th of November 2011
//--------------------------------------------------------------------------------------
#define DEBUG
//---------------------------------------------------------------------
// RF12 link - JeeLabs
//---------------------------------------------------------------------
#include <Ports.h>
#include <RF12.h>

#define MYNODE 35            // node ID 30 reserved for base station
#define freq RF12_433MHZ     // frequency
#define group 210            // network group 

// The RF12 data payload - a neat way of packaging data when sending via RF - JeeLabs
typedef struct
{
  int ct1;		    // current transformer 1
  int supplyV;              // emontx voltage
} Payload;
Payload emontx;              

//---------------------------------------------------------------------
// The PacketBuffer class is used to generate the json string that is send via ethernet - JeeLabs
//---------------------------------------------------------------------
class PacketBuffer : public Print {
public:
    PacketBuffer () : fill (0) {}
    const char* buffer() { return buf; }
    byte length() { return fill; }
    void reset()
    { 
      memset(buf,NULL,sizeof(buf));
      fill = 0; 
    }
    virtual void write(uint8_t ch)
        { if (fill < sizeof buf) buf[fill++] = ch; }
    byte fill;
    char buf[150];
    private:
};
PacketBuffer str;

//---------------------------------------------------------------------
// Ethernet - Andrew Lindsay
//---------------------------------------------------------------------
#include <EtherShield.h>
byte mac[6] =     { 0x04,0x13,0x31,0x13,0x05,0x22};           // Unique mac address - must be unique on your local network

#define PACHUBE_VHOST "api.pachube.com"
#define PACHUBEAPIKEY "X-PachubeApiKey: xxxxxxxxxxxxxxxxxxxxxxx" 
#define PACHUBEAPIURL "/v2/feeds/38233.csv"

byte server[4] = {173,203,98,29};
//---------------------------------------------------------------------

// Flow control varaiables
int dataReady=0;                                                  // is set to 1 when there is data ready to be sent
unsigned long lastRF;                                             // used to check for RF recieve failures
int post_count;                                                   // used to count number of ethernet posts that dont recieve a reply
    
//---------------------------------------------------------------------
// Setup
//---------------------------------------------------------------------
void setup()
{
  Serial.begin(9600);
  Serial.println("Emonbase:NanodeRF ctonly");
  Serial.print("Node: "); Serial.print(MYNODE); 
  Serial.print(" Freq: "); Serial.print("433Mhz"); 
  Serial.print(" Network group: "); Serial.println(group);
  Serial.print("Posting to "); printIP(server); Serial.print(" "); Serial.println(PACHUBE_VHOST);

  
  ethernet_setup_dhcp(mac,server,80,8); // Last two: PORT and SPI PIN: 8 for Nanode, 10 for nuelectronics
  
  rf12_initialize(MYNODE, freq,group);
  lastRF = millis()-40000;                                        // setting lastRF back 40s is useful as it forces the ethernet code to run straight away
                                                                  // which means we dont have to wait to see if its working
  pinMode(6, OUTPUT); digitalWrite(6,LOW);                       // Nanode indicator LED setup, HIGH means off! if LED lights up indicates that Etherent and RFM12 has been initialize
}

//-----------------------------------------------------------------------
// Loop
//-----------------------------------------------------------------------
void loop()
{
digitalWrite(6,HIGH);    //turn inidicator LED off! yes off! input gets inverted by buffer
  //---------------------------------------------------------------------
  // On data receieved from rf12
  //---------------------------------------------------------------------
  if (rf12_recvDone() && rf12_crc == 0 && (rf12_hdr & RF12_HDR_CTL) == 0) 
  {
    digitalWrite(6,LOW);                                         // Flash LED on recieve ON
    emontx=*(Payload*) rf12_data;                                 // Get the payload

    dataReady = 1;                                                // Ok, data is ready
    lastRF = millis();                                            // reset lastRF timer
    digitalWrite(6,HIGH);                                          // Flash LED on recieve OFF
  }
  

  
  //----------------------------------------
  // 2) Send the data
  //----------------------------------------
  if (ethernet_ready_dhcp() && dataReady==1)                      // If ethernet and data is ready: send data
  {
    str.reset();
    str.print("power,");
    str.print(emontx.ct1);

    #ifdef DEBUG
    Serial.print(str.buf);                                        // Print final json string to terminal
    #endif
    
    ethernet_send_post(PSTR(PACHUBEAPIURL),PSTR(PACHUBE_VHOST),PSTR(PACHUBEAPIKEY), PSTR("PUT "),str.buf);
    #ifdef DEBUG
    Serial.println("sent"); 
    #endif
    dataReady = 0;                        // reset dataReady
  }
  
}


