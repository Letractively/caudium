/* $Id$
 *
 * CaudiumSSL packet layer
 */


object current_read_state;
object current_write_state;
string left_over;
object packet;

int dying;
int closing;

function(object,int|object,string:void) alert_callback;

inherit "constants";
inherit "handshake";

constant Queue = ADT.Queue;
constant State = CaudiumSSL.state;

constant PRI_alert = 1;
constant PRI_urgent = 2;
constant PRI_application = 3;

inherit Queue : alert;
inherit Queue : urgent;
inherit Queue : application;

void create(int is_server)
{
  alert::create();
  urgent::create();
  application::create();
  current_read_state = State(this_object());
  current_write_state = State(this_object());
  handshake::create(is_server);
}

/* Called with alert object, sequence number of bad packet,
 * and raw data as arguments, if a bad packet is received.
 *
 * Can be used to support a fallback redirect https->http
 */
void set_alert_callback(function(object,int|object,string:void) callback)
{
  alert_callback = callback;
}

static object recv_packet(string data)
{
  mixed res;

#ifdef CaudiumSSL3_DEBUG
//  werror(sprintf("CaudiumSSL.connection->recv_packet(%O)\n", data));
#endif
  if (left_over || !packet)
  {
    packet = Packet(2048);
    res = packet->recv( (left_over || "")  + data, version[1]);
  }
  else
    res = packet->recv(data,version[1]);

  if (stringp(res))
  { /* Finished a packet */
    left_over = res;
    if (current_read_state) {
#ifdef CaudiumSSL3_DEBUG
      werror("Decrypting packet.. version[1]="+version[1]+"\n");
#endif /* CaudiumSSL3_DEBUG */
      return current_read_state->decrypt_packet(packet,version[1]);
    } else {
#ifdef CaudiumSSL3_DEBUG
      werror(sprintf("CaudiumSSL.connection->recv_packet(): current_read_state is zero!\n"));
#endif /* CaudiumSSL3_DEBUG */
      return 0;
    }
  }
  else /* Partial packet read, or error */
    left_over = 0;
  return res;
}

/* Handshake and and change cipher must use the same priority,
 * so must application data and close_notifies. */
void send_packet(object packet, int|void priority)
{


  #ifdef CaudiumSSL3_FRAGDEBUG
  werror(" CaudiumSSL.connection->send_packet: strlen(packet)="+strlen(packet)+"\n");
  #endif
  if (!priority)
    priority = ([ PACKET_alert : PRI_alert,
		  PACKET_change_cipher_spec : PRI_urgent,
	          PACKET_handshake : PRI_urgent,
		  PACKET_application_data : PRI_application ])[packet->content_type];
#ifdef CaudiumSSL3_DEBUG
#if 0
  if (packet->content_type == 22)
    werror(sprintf("CaudiumSSL.connection->send_packet() called from:\n"
		   "%s\n", describe_backtrace(backtrace())));
#endif
  werror(sprintf("CaudiumSSL.connection->send_packet: type %d, %d, '%O'\n",
		 packet->content_type, priority,  packet->fragment[..5]));
#endif
  switch (priority)
  {
  default:
    throw( ({"CaudiumSSL.connection->send_packet: internal error\n", backtrace() }) );
  case PRI_alert:
    alert::put(packet);
    break;
  case PRI_urgent:
    urgent::put(packet);
    break;
  case PRI_application:
    application::put(packet);
    break;
  }
}

/* Returns a string of data to be written, "" if there's no pending packets,
 * 1 if the connection is being closed politely, and -1 if the connection
 * died unexpectedly. */
string|int to_write()
{
  if (dying)
    return -1;
  if (closing) {
    return 1;
  }
  object packet = alert::get() || urgent::get() || application::get();
  if (!packet)
    return "";

#ifdef CaudiumSSL3_DEBUG
  werror(sprintf("CaudiumSSL.connection: writing packet of type %d, %O\n",
		 packet->content_type, packet->fragment[..6]));
#endif
  if (packet->content_type == PACKET_alert)
  {
    if (packet->level == ALERT_fatal)
      dying = 1;
    else
      if (packet->description == ALERT_close_notify)
	closing = 1;
  }
  string res = current_write_state->encrypt_packet(packet,version[1])->send();
  if (packet->content_type == PACKET_change_cipher_spec)
    current_write_state = pending_write_state;
  return res;
}

void send_close()
{
  send_packet(Alert(ALERT_warning, ALERT_close_notify,version[1]), PRI_application);
}

int handle_alert(string s)
{
  int level = s[0];
  int description = s[1];

  //FIXME  Include the TLS alerts in ALERT_levels and ALERT_descriptopns aswell!!
  if (! (ALERT_levels[level] && ALERT_descriptions[description]))
  {
    send_packet(Alert(ALERT_fatal, ALERT_unexpected_message,version[1],
		      "CaudiumSSL.connection->handle_alert: invalid alert\n", backtrace()));
    return -1;
  }
  if (level == ALERT_fatal)
  {
#ifdef CaudiumSSL3_DEBUG
    werror(sprintf("CaudiumSSL.connection: Fatal alert %d\n", description));
#endif
    return -1;
  }
  if (description == ALERT_close_notify)
  {
#ifdef CaudiumSSL3_DEBUG
    werror(sprintf("CaudiumSSL.connection: Close notify  alert %d\n", description));
#endif
    return 0;
//     return 1;			// looses data
  }
  if (description == ALERT_no_certificate)
  {
#ifdef CaudiumSSL3_DEBUG
    werror(sprintf("CaudiumSSL.connection: No certificate  alert %d\n", description));
#endif

    if ((certificate_state == CERT_requested) && (auth_level == AUTHLEVEL_ask))
    {
      certificate_state = CERT_no_certificate;
      return 0;
    } else {
      send_packet(Alert(ALERT_fatal, ((certificate_state == CERT_requested)
			       ? ALERT_handshake_failure
				: ALERT_unexpected_message),version[1]));
      return -1;
    }
  }
  else
    werror(sprintf("CaudiumSSL.connection: Received warning alert %d\n", description));
  return 0;
}

int handle_change_cipher(int c)
{
  if (!expect_change_cipher || (c != 1))
  {
#ifdef CaudiumSSL3_DEBUG
    werror("CaudiumSSL.connection: handle_change_cipher: Unexcepted message!");
#endif
    send_packet(Alert(ALERT_fatal, ALERT_unexpected_message,version[1]));
    return -1;
  }
  else
  {
    current_read_state = pending_read_state;
    expect_change_cipher = 0;
    return 0;
  }
}

string alert_buffer = "";
string handshake_buffer = "";
int handshake_finished = 0;

/* Returns a string of application data, 1 if connection was closed, or
 * -1 if a fatal error occured */
string|int got_data(string|int s)
{
  if(!stringp(s)) {
    return s;
  }
  /* If alert_callback is called, this data is passed as an argument */
  string alert_context = (left_over || "") + s;

  string res = "";
  object packet;
  while (packet = recv_packet(s))
  {
    s = "";

    if (packet->is_alert)
    { /* Reply alert */
#ifdef CaudiumSSL3_DEBUG
      werror("CaudiumSSL.connection: Bad received packet\n");
#endif
      send_packet(packet);
      if (alert_callback)
	alert_callback(packet, current_read_state->seq_num, alert_context);
      if ((!packet) || (!this_object()) || (packet->level == ALERT_fatal))
	return -1;
    }
    else
    {
#ifdef CaudiumSSL3_DEBUG
      werror(sprintf("CaudiumSSL.connection: received packet of type %d\n",
		     packet->content_type));
#endif
      switch (packet->content_type)
      {
      case PACKET_alert:
       {
	 int i;
	 mixed err = 0;
	 alert_buffer += packet->fragment;
	 for (i = 0;
	      !err && ((strlen(alert_buffer) - i) >= 2);
	      i+= 2)
	   err = handle_alert(alert_buffer[i..i+1]);

	 alert_buffer = alert_buffer[i..];
	 if (err)
	   return err;
	 break;
       }
      case PACKET_change_cipher_spec:
       {
	 int i;
	 int err;
	 for (i = 0; (i < strlen(packet->fragment)); i++)
	 {
	   err = handle_change_cipher(packet->fragment[i]);
#ifdef CaudiumSSL3_DEBUG
	   werror(sprintf("tried change_cipher: %d\n", err));
#endif
	   if (err)
	     return err;
	 }
	 break;
       }
      case PACKET_handshake:
       {
	 if (expect_change_cipher)
	 {
	   /* No change_cipher message was recieved */
	   send_packet(Alert(ALERT_fatal, ALERT_unexpected_message,version[1]));
	   return -1;
	 }
	 mixed err;
	 int len;
	 handshake_buffer += packet->fragment;

	 while (strlen(handshake_buffer) >= 4)
	 {
	   sscanf(handshake_buffer, "%*c%3c", len);
	   if (strlen(handshake_buffer) < (len + 4))
	     break;
	   err = handle_handshake(handshake_buffer[0],
				  handshake_buffer[4..len + 3],
				  handshake_buffer[.. len + 3]);
	   handshake_buffer = handshake_buffer[len + 4..];
	   if (err < 0)
	     return err;
	   if (err > 0) {
	     handshake_finished = 1;
	   }
	 }
	 break;
       }
      case PACKET_application_data:
	if (!handshake_finished)
	{
	  send_packet(Alert(ALERT_fatal, ALERT_unexpected_message,version[1]));
	  return -1;
	}
	res += packet->fragment;
	break;
      case PACKET_V2:
       {
	 mixed err = handle_handshake(HANDSHAKE_hello_v2,
				      packet->fragment[1 .. ],
				      packet->fragment);
	 if (err)
	   return err;
       }
      }
    }
  }
  return res;
}

