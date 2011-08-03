//--------------------------------------------------------
//   EtherShield examples: simple client functions
//
//   simple client code layer:
//
// - ethernet_setup(mac,ip,gateway,server,port)
// - ethernet_ready() - check this before sending
//
// - ethernet_setup_dhcp(mac,serverip,port)
// - ethernet_ready_dhcp() - check this before sending
//
// - ethernet_setup_dhcp_dns(mac,domainname,port)
// - ethernet_ready_dhcp_dns() - check this before sending
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

//#define DEBUG

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
// DHCP only
//------------------------------------------------------------------------------------------------
void ethernet_setup_dhcp(byte* in_mymac,byte* in_websrvip, int in_port,int spipin)
{
  mymac = in_mymac;
  websrvip = in_websrvip;
  
  es.ES_enc28j60SpiInit();
  es.ES_enc28j60Init(mymac,spipin);
  es.ES_client_set_wwwip(websrvip);  // target web server
  port = in_port;
}

int ethernet_ready_dhcp()
{
  if (es.ES_dhcp_state() == DHCP_STATE_OK ) 
  {
    plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
    dat_p=es.ES_packetloop_icmp_tcp(buf,plen);
    if (dat_p==0) return 1; else return 0;
  }
  {
    long lastDnsRequest = 0L;
    long lastDhcpRequest = millis();
    uint8_t dhcpState = 0;
    boolean gotIp = false;
    
    es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );    
    while( !gotIp ) 
    {
      //dns_state=DNS_STATE_INIT;
      
      plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
      dat_p=es.ES_packetloop_icmp_tcp(buf,plen);
      
      if(dat_p==0) {
        
        int retstat = es.ES_check_for_dhcp_answer( buf, plen);
        dhcpState = es.ES_dhcp_state();
        
        // we are idle here
        if( dhcpState != DHCP_STATE_OK ) {
          if (millis() > (lastDhcpRequest + 10000L) ){
            lastDhcpRequest = millis();
            // send dhcp
            #ifdef DEBUG
            Serial.println("Sending DHCP Request");
            #endif
            es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );
          }
        } 
        else {
          if( !gotIp ) {
            #ifdef DEBUG
            // Display the results:
            Serial.print( "My IP: " );
            printIP( myip );
            Serial.println();

            Serial.print( "Netmask: " );
            printIP( mynetmask );
            Serial.println();

            Serial.print( "DNS IP: " );
            printIP( dnsip );
            Serial.println();

            Serial.print( "GW IP: " );
            printIP( gwip );
            Serial.println();
            #endif
            gotIp = true;

            //init the ethernet/ip layer:
            es.ES_init_ip_arp_udp_tcp(mymac, myip, port);

            // Set the Router IP
            es.ES_client_set_gwip(gwip);  // e.g internal IP of dsl router

            // Set the DNS server IP address if required, or use default
            es.ES_dnslkup_set_dnsip( dnsip );
          }
        }
      }
    }
  }
}

//------------------------------------------------------------------------------------------------
// DHCP and DNS
//------------------------------------------------------------------------------------------------
void ethernet_setup_dhcp_dns(byte* in_mymac,char* in_webserver_vhost ,int in_port,int spipin)
{
  mymac = in_mymac;
  webserver_vhost = in_webserver_vhost;
  
  es.ES_enc28j60SpiInit();
  es.ES_enc28j60Init(mymac,spipin);
  port = in_port;
}

int ethernet_ready_dhcp_dns()
{  
  if (es.ES_dhcp_state() == DHCP_STATE_OK ) 
  {
    plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
    dat_p=es.ES_packetloop_icmp_tcp(buf,plen);
    
    if( plen > 0 ) 
    {
      // We have a packet
      // Check if IP data
      if (dat_p == 0) 
      {
        
        if (es.ES_client_waiting_gw() )
        {
          // No ARP received for gateway
          return 0;
        }
        
        if (dns_state==DNS_STATE_INIT)
        {
          #ifdef DEBUG
            Serial.println("Request DNS" );
          #endif
          //sec=0;
          dns_state=DNS_STATE_REQUESTED;
          lastDnsRequest = millis();
          es.ES_dnslkup_request(buf,(uint8_t*)webserver_vhost);
          return 0;
        }
        
        if (dns_state==DNS_STATE_REQUESTED && es.ES_udp_client_check_for_dns_answer( buf, plen ) )
        {
          #ifdef DEBUG
            Serial.println( "DNS Answer");
          #endif
          dns_state=DNS_STATE_ANSWER;
          es.ES_client_set_wwwip(es.ES_dnslkup_getip());
        }
        
        if (dns_state!=DNS_STATE_ANSWER)
        {
          // retry every minute if dns-lookup failed:
          if (millis() > (lastDnsRequest + 10000L) )
          {
            dns_state=DNS_STATE_INIT;
            lastDnsRequest = millis();
          }
          // don't try to use web client before
          // we have a result of dns-lookup
          return 0;
        }
      }
      else {
        if (dns_state==DNS_STATE_REQUESTED && es.ES_udp_client_check_for_dns_answer( buf, plen ) )
        {
          dns_state=DNS_STATE_ANSWER;
          #ifdef DEBUG
            Serial.println( "DNS Answer 2");
          #endif
          es.ES_client_set_wwwip(es.ES_dnslkup_getip());
        }
        
       
      }
    }
    
    if( dns_state == DNS_STATE_ANSWER)
    {
      return 1;
    } 
    else
    {
      // retry every minute if dns-lookup failed:
      if (millis() > (lastDnsRequest + 10000L) )
      {
        #ifdef DEBUG
          Serial.println("Timeout. Request DNS");
        #endif
        dns_state=DNS_STATE_REQUESTED;
        lastDnsRequest = millis();
        es.ES_dnslkup_request(buf,(uint8_t*)webserver_vhost);
      }
      // don't try to use web client before
      // we have a result of dns-lookup
    }
  }
  else
  {
    long lastDnsRequest = 0L;
    long lastDhcpRequest = millis();
    uint8_t dhcpState = 0;
    boolean gotIp = false;
    
    es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );    
    while( !gotIp ) 
    {
      dns_state=DNS_STATE_INIT;
      
      plen = es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf);
      dat_p=es.ES_packetloop_icmp_tcp(buf,plen);
      
      if(dat_p==0) {
        
        int retstat = es.ES_check_for_dhcp_answer( buf, plen);
        dhcpState = es.ES_dhcp_state();
        
        // we are idle here
        if( dhcpState != DHCP_STATE_OK ) {
          if (millis() > (lastDhcpRequest + 10000L) ){
            lastDhcpRequest = millis();
            // send dhcp
            #ifdef DEBUG
            Serial.println("Sending DHCP Request");
            #endif
            es.ES_dhcp_start( buf, mymac, myip, mynetmask,gwip, dnsip, dhcpsvrip );
          }
        } 
        else {
          if( !gotIp ) {

            #ifdef DEBUG
            // Display the results:
            Serial.print( "My IP: " );
            printIP( myip );
            Serial.println();

            Serial.print( "Netmask: " );
            printIP( mynetmask );
            Serial.println();

            Serial.print( "DNS IP: " );
            printIP( dnsip );
            Serial.println();

            Serial.print( "GW IP: " );
            printIP( gwip );
            Serial.println();
            #endif
            
            gotIp = true;

            //init the ethernet/ip layer:
            es.ES_init_ip_arp_udp_tcp(mymac, myip, port);

            // Set the Router IP
            es.ES_client_set_gwip(gwip);  // e.g internal IP of dsl router

            // Set the DNS server IP address if required, or use default
            es.ES_dnslkup_set_dnsip( dnsip );
          }
        }
      }
    }
  }
  return 0;
}

//------------------------------------------------------------------------------------------------
// Send
//------------------------------------------------------------------------------------------------

void ethernet_send(char * apiurl,char * host,char * apikey,char * putget,char * string)
{
  //es.ES_client_browse_url(PSTR("/api/22274.csv"),"20.0,30.0", domainname, &browserresult_callback);
  es.ES_client_http_post(PSTR(""),PSTR("www.dev.openenergymonitor.org"),NULL,PSTR("GET "),NULL, &browserresult_callback);
}

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
