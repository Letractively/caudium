#!/usr/local/bin/pike

// $Id$

void cb_clog(array foo) {

 if ((foo[11] == "/supports") && (foo[10]=="GET")) {
   write(sprintf("INSERT INTO support (host,version,timestmp) VALUES (\"%s\",\"%s\",\"%d-%02d-%02d %02d:%02d:%02d\");\n",foo[0],_Roxen.http_decode_string(foo[2])-"Caudium/",foo[3],foo[4],foo[5],foo[6],foo[7],foo[8]));
 }
}

void main() {
 
  CommonLog->read(cb_clog, "/var/hosting/caudium/logs/caudium.net.200207");
  CommonLog->read(cb_clog, "/var/hosting/caudium/logs/caudium.net.200208");
  CommonLog->read(cb_clog, "/var/hosting/caudium/logs/caudium.net.200209");
  CommonLog->read(cb_clog, "/var/hosting/caudium/logs/caudium.net.200210");

} 
