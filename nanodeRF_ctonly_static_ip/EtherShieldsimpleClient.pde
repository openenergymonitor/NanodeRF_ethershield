//--------------------------------------------------------
//   EtherShield examples: simple client functions
//
//   simple client code layer:
//
// - ethernet_setup(mac,ip,gateway,server,port)
// - ethernet_ready() - check this before sending
//
//   Posting data within request body:
// - ethernet_send_post(PSTR(PACHUBEAPIURL),PSTR(PACHUBE_VHOST),PSTR(PACHUBEAPIKEY), PSTR("PUT "),str);
// 
//   Sending data in the URL
// - ethernet_send_url(PSTR(HOST),PSTR(API),str);
//
//   EtherShield library by: Andrew D Lindsay
//   http://blog.thiseldo.co.uk
//
//   Example by Trystan Lea, building on Andrew D Lindsay's examples
//
//   Projects: Nanode.eu and OpenEnergyMonitor.org
//   Licence: GPL GNU v3
//--------------------------------------------------------

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
long lastDhcpRequest = 0L;

int retstat, lastretstat;

boolean gotIp = false;

static int8_t dns_state=DNS_STATE_INIT;

void printIP( uint8_t *buf ) {
  for( int i = 0; i < 4; i++ ) {
    Serial.print( buf[i], DEC );
    if( i<3 )
      Serial.print( "." );
  }
}

//------------------------------------------------------------------------------------------------
// Manual entry ip addresses only
//------------------------------------------------------------------------------------------------
void ethernet_setup(byte* mymac,byte* myip,byte* gateway,byte* server, int port,int spipin)
{
  es.ES_enc28j60SpiInit();
  es.ES_enc28j60Init(mymac,spipin);
  es.ES_init_ip_arp_udp_tcp(mymac, myip, port);
  es.ES_client_set_gwip(gateway);
  es.ES_client_set_wwwip(server);
}

int ethernet_ready()
{
  plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
  dat_p=es.ES_packetloop_icmp_tcp(buf,plen);
  if (dat_p==0) return 1; else return 0;
}
    
//------------------------------------------------------------------------------------------------
// Send
//------------------------------------------------------------------------------------------------

void ethernet_send_url(char * hoststr, char * urlbuf,char * urlbuf_varpart)
{
  data_recieved = 0;
  es.ES_client_browse_url(urlbuf,urlbuf_varpart,hoststr,&browserresult_callback);
}

void ethernet_send_post(char * urlbuf,char * hoststr,char * additionalheaderline,char * method,char * postval)
{
  es.ES_client_http_post(urlbuf,hoststr,additionalheaderline,method,postval, &browserresult_callback);
}

void browserresult_callback(uint8_t statuscode,uint16_t datapos) 
{
  if (datapos != 0)
  {
    uint16_t pos = datapos;
    #ifdef DEBUG
    while (buf[pos])
    {
      Serial.print(buf[pos]);
      pos++;
    }
    #endif
    data_recieved = 1;
  }
}

int reply_recieved()
{
  return data_recieved;
}


