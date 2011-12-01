/*                          _                                                      _      
                           | |                                                    | |     
  ___ _ __ ___   ___  _ __ | |__   __ _ ___  ___       _ __   __ _ _ __   ___   __| | ___ 
 / _ \ '_ ` _ \ / _ \| '_ \| '_ \ / _` / __|/ _ \     | '_ \ / _` | '_ \ / _ \ / _` |/ _ \
|  __/ | | | | | (_) | | | | |_) | (_| \__ \  __/  _  | | | | (_| | | | | (_) | (_| |  __/
 \___|_| |_| |_|\___/|_| |_|_.__/ \__,_|___/\___| (_) |_| |_|\__,_|_| |_|\___/ \__,_|\___|
                                                                                          
*/
//--------------------------------------------------------------------------------------
// Example of posting data from a nanode to 2 different server's
// Uses Andrew Lindsay's EtherShield library - using DHCP

// Trystan Lea and Glyn Hudson
// openenergymonitor.org
// GNU GPL V3
//--------------------------------------------------------------------------------------
//#define DEBUG
#include <Ports.h>
#include <RF12.h>

// Include a watchdog, to watch stalling ethernet connections
// The uno (optiboot) bootloader must be used !!
// See http://jeelabs.org/2010/06/09/repairing-a-faulty-atmega/ using a JeeNode as ISP programmes
// with the isp_repair2 sketch http://jeelabs.net/projects/cafe/repository/show/Ports/examples/isp_repair2
#include <avr/wdt.h>

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
    virtual size_t write(uint8_t ch)
        { if (fill < sizeof buf) buf[fill++] = ch; }
    byte fill;
    char buf[150];
    private:
};

PacketBuffer str;
PacketBuffer postval;

//---------------------------------------------------------------------
// Ethernet - Andrew Lindsay
//---------------------------------------------------------------------
#include <EtherShield.h>
byte mac[6] = { 0x04,0x13,0x31,0x13,0x02,0x49};           // Unique mac address - must be unique on your local network

#define HOST1 ""                                                   // Blank "" if on your local network: www.yourdomain.org if not
#define API1  "/emoncms2/api/post?apikey=99d52ad247c3ffff39b12cedc408f38d&json="  // Your api url including APIKEY
byte server1[4] = {31,222,163,58};

#define HOST2 "emonweb.org"
#define API2  "/api"
byte server2[4]= {174,129,212,2};

// Flow control varaiables
int dataReady=0;                                                  // is set to 1 when there is data ready to be sent
unsigned long lastRF;                                             // used to check for RF recieve failures
int post_count;

int state = 0;                                                    // Send data to server 1 first

//---------------------------------------------------------------------
// Setup
//---------------------------------------------------------------------
void setup()
{
  Serial.begin(9600);
  Serial.println("Nanode sending to multiple servers");
  Serial.print("Node: "); Serial.print(MYNODE); 
  Serial.print(" Freq: "); Serial.print("433Mhz"); 
  Serial.print(" Network group: "); Serial.println(group);

  ethernet_setup_dhcp(mac,80,8); // Last two: PORT and SPI PIN: 8 for Nanode, 10 for nuelectronics

  rf12_initialize(MYNODE, freq,group);
  lastRF = millis()-40000;                                        // setting lastRF back 40s is useful as it forces the ethernet code to run straight away

  pinMode(6, OUTPUT); digitalWrite(6,LOW);                       // Nanode indicator LED setup, HIGH means off! if LED lights up indicates that Etherent and RFM12 has been initialize
  wdt_enable(WDTO_8S);
}

//-----------------------------------------------------------------------
// Loop
//-----------------------------------------------------------------------
void loop()
{
  wdt_reset();
  if ((millis()-lastRF)>5000)
  {
    if (rf12_recvDone() && rf12_crc == 0 && (rf12_hdr & RF12_HDR_CTL) == 0) 
    {
      digitalWrite(6,LOW);                                         // Flash LED on recieve ON
      emontx=*(Payload*) rf12_data;                                 // Get the payload

      // JSON creation: JSON sent are of the format: {key1:value1,key2:value2} and so on
      str.reset();                                                  // Reset json string      
      str.print("{RFfail01:0,");                                    // RF recieved so no failure
      str.print("nanode01_ct:");    str.print(emontx.ct1);          // Add CT 1 reading 
      str.print(",nanode01_v:");    str.print(emontx.supplyV);      // Add Emontx battery voltage reading

      postval.reset();
      postval.print("auth_token=QfDwhcf3QAc2Reezwba5&electra=");
      postval.print(emontx.ct1);

      state = 1;
      lastRF = millis();                                            // reset lastRF timer
      digitalWrite(6,HIGH);                                          // Flash LED on recieve OFF
    }

    // If no data is recieved from rf12 module the server is updated every 30s with RFfail = 1 indicator for debugging
    if ((millis()-lastRF)>30000)
    {
      lastRF = millis();                                            // reset lastRF timer
      str.reset();                                                  // reset json string
      str.print("{RFfail01:1");                                       // No RF received in 30 seconds so send failure 
      state = 1;                                            // Ok, data is ready
    }
  }

  if (state==1) 
  { 
    Serial.println("Setting ip to server 1");
    ethernet_set_server(server1); state = 2; 
  }

  if (ethernet_ready_dhcp() && state == 2 )
  {
    if (reply_recieved()==0) post_count++; else post_count = 0;   // Counts number of times a reply was not recieved
    str.print(",POSTfail01:"); str.print(post_count); str.print("}\0");// Posts number of times a reply was not recieved

    Serial.println("Sending to server 1");
    Serial.println(str.buf);    // Print final json string to terminal

    ethernet_send_url(PSTR(HOST1),PSTR(API1),str.buf);
    state = 3;
  }

  if (state==3 && reply_recieved())
  {
    Serial.println("Setting ip to server 2");
    state = 4;
    ethernet_set_server(server2);
  }

  if (ethernet_ready_dhcp() && state==4)
  {
    Serial.println("Sending to server 2");
    Serial.println(postval.buf);
    ethernet_send_post(PSTR(API2), PSTR(HOST2), NULL, NULL, postval.buf);
    state = 0;
  }

}

