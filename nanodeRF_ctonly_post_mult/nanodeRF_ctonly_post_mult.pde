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
#define DEBUG

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

#define HOST1 ""                                                   // Blank "" if on your local network: www.yourdomain.org if not
#define API1 "/emoncms2/api/post?apikey=XXXXXXXXXXXXXXXXXX&json="  // Your api url including APIKEY
byte server1[4] = {00,00,00,00};                                   // Server IP

#define HOST2 ""                                                   // Blank "" if on your local network: www.yourdomain.org if not
#define API2 "/emoncms2/api/post?apikey=XXXXXXXXXXXXXXXXXX&json="  // Your api url including APIKEY
byte server2[4] = {00,00,00,00};                                   // Server IP
//---------------------------------------------------------------------

// Flow control varaiables
int dataReady=0;                                                  // is set to 1 when there is data ready to be sent
unsigned long lastRF;                                             // used to check for RF recieve failures

int state = 0;                                                // Send data to server 1 first

//---------------------------------------------------------------------
// Setup
//---------------------------------------------------------------------
void setup()
{
  Serial.begin(9600);
  Serial.println("Nanode sending to multiple servers");

  ethernet_setup_dhcp(mac,80,8); // Last two: PORT and SPI PIN: 8 for Nanode, 10 for nuelectronics
  lastRF = millis()-40000;
}

//-----------------------------------------------------------------------
// Loop
//-----------------------------------------------------------------------
void loop()
{
  if ((millis()-lastRF)>5000)
  {
    lastRF = millis();                                            // reset timer
    
    str.reset(); str.print("{test:123.4}\0");
    Serial.print(str.buf);
    
    state = 1;
  }
  
  if (state==1) 
  { 
    Serial.println("Setting ip to server 1");
    ethernet_set_server(server1); state = 2; 
  }
  
  if (ethernet_ready_dhcp() && state==2)
  {
    Serial.println("Sending to server 1");
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
    ethernet_send_url(PSTR(HOST2),PSTR(API2),str.buf);
    state = 0;
  } 
}

