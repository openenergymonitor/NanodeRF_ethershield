/*                          _                                                      _      
                           | |                                                    | |     
  ___ _ __ ___   ___  _ __ | |__   __ _ ___  ___       _ __   __ _ _ __   ___   __| | ___ 
 / _ \ '_ ` _ \ / _ \| '_ \| '_ \ / _` / __|/ _ \     | '_ \ / _` | '_ \ / _ \ / _` |/ _ \
|  __/ | | | | | (_) | | | | |_) | (_| \__ \  __/  _  | | | | (_| | | | | (_) | (_| |  __/
 \___|_| |_| |_|\___/|_| |_|_.__/ \__,_|___/\___| (_) |_| |_|\__,_|_| |_|\___/ \__,_|\___|
                                                                                          
*/
//--------------------------------------------------------------------------------------
// Relay's data recieved by emontx up to emoncms
// Minimal CT and supply voltage only version

// Uses JeeLabs RF12 library http://jeelabs.org/2009/02/10/rfm12b-library-for-arduino/
// Uses Andrew Lindsay's EtherShield library - using DHCP

// By Glyn Hudson and Trystan Lea
// openenergymonitor.org
// GNU GPL V3

// Last update: 2nd of August 2011
//--------------------------------------------------------------------------------------

//---------------------------------------------------------------------
// RF12 link - JeeLabs
//---------------------------------------------------------------------
#include <Ports.h>
#include <RF12.h>
#include <EtherShield.h>

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
//    virtual void write(uint8_t ch)
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

byte mac[6] =     { 0x04,0x13,0x31,0x13,0x02,0x49};           // Unique mac address - must be unique on your local network
#define HOST ""                                                   // Blank "" if on your local network: www.yourdomain.org if not
#define API "/emoncms2/api/post?apikey=99d52ad247c3ffff39b12cedc408f38d&json="  // Your api url including APIKEY

#define EMONWEBHOST "emonweb.org"
#define API_URL "/api"


int data_recieved = 0;

byte* mymac;
static uint8_t myip[4] =      { 0,0,0,0 };
static uint8_t mynetmask[4] = { 0,0,0,0 };
byte* websrvip;
static uint8_t gwip[4] =      { 0,0,0,0 };
static uint8_t dnsip[4] =     { 0,0,0,0 };
static uint8_t dhcpsvrip[4] = { 0,0,0,0 };

char* webserver_vhost;

EtherShield es=EtherShield();

#define BUFFER_SIZE 500
static uint8_t buf[BUFFER_SIZE+1];
uint16_t dat_p;
int plen = 0;

int port;

long lastDnsRequest = 0L;

static int8_t dns_state=DNS_STATE_INIT;


byte server[4] = {31,222,163,58};  // Server IP
byte emonweb_server[4]= {174,129,212,2};

//---------------------------------------------------------------------

// Flow control varaiables
int dataReady=0;                                                  // is set to 1 when there is data ready to be sent
unsigned long lastRF;                                             // used to check for RF recieve failures
int post_count;                                             // used to count number of ethernet posts that dont recieve a reply
    
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
  Serial.print("Posting to "); printIP(server); Serial.print(" "); Serial.println(HOST);

//  ethernet_setup_dhcp(mac,server,80,8); // Last two: PORT and SPI PIN: 8 for Nanode, 10 for nuelectronics*/
  mymac = mac;
  es.ES_enc28j60SpiInit();
  es.ES_enc28j60Init(mac,8);
  es.ES_client_set_wwwip(server);  // target web server
  port = 80;
  ethernet_ready_dhcp();

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
    // emontx_nodeID=rf12_hdr & 0x1F;   //extract node ID from received packet 

    // JSON creation: JSON sent are of the format: {key1:value1,key2:value2} and so on
    str.reset();                                                  // Reset json string      
    str.print("{RFfail01:0,");                                    // RF recieved so no failure
    str.print("nanode01_ct:");    str.print(emontx.ct1);          // Add CT 1 reading 
    str.print(",nanode01_v:");    str.print(emontx.supplyV);      // Add Emontx battery voltage reading

    postval.reset();
    postval.print("auth_token=QfDwhcf3QAc2Reezwba5&electra=");
    postval.print(emontx.ct1);

    dataReady = 1;                                                // Ok, data is ready
    lastRF = millis();                                            // reset lastRF timer
    digitalWrite(6,HIGH);                                          // Flash LED on recieve OFF
  }

  // If no data is recieved from rf12 module the server is updated every 30s with RFfail = 1 indicator for debugging
  if ((millis()-lastRF)>30000)
  {
    lastRF = millis();                                            // reset lastRF timer
    str.reset();                                                  // reset json string
    str.print("{RFfail01:1");                                       // No RF received in 30 seconds so send failure 
    dataReady = 1;                                                // Ok, data is ready
  }

  //----------------------------------------
  // 2) Send the data
  //----------------------------------------

  if (ethernet_ready() && dataReady==1)                      // If ethernet and data is ready: send data
  {
    if (reply_recieved()==0) post_count++; else post_count = 0;   // Counts number of times a reply was not recieved
    str.print(",POSTfail01:"); str.print(post_count); str.print("}\0");// Posts number of times a reply was not recieved
    Serial.print(str.buf);    // Print final json string to terminal

    es.ES_client_set_wwwip(server);
    ethernet_send_url(PSTR(HOST),PSTR(API),str.buf);              // Send the data via ethernet
    Serial.println("sent"); dataReady = 0;                        // reset dataReady

    if (ethernet_ready()) 
    {
      es.ES_client_set_wwwip(emonweb_server);
      ethernet_send_post(PSTR(API_URL), PSTR(EMONWEBHOST), NULL, NULL, postval.buf);
      Serial.println("Posted to emonweb.org:");
      Serial.println(postval.buf);
    }
  }  
}
