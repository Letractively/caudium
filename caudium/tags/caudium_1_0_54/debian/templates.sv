Template: caudium/config_port
Type: string
Default: 22202
Description: On what port should the config interface be?
 Specify the port on which Caudium will provide its configuration
 interface. You can access the interface using any form capable
 web browser (like Mozilla, Lynx, Links or Galeon)
Description-sv: På vilken port skall konfigurationsgränssnittet vara?
 Ange vilken port som Caudium skall tillhandahålla sitt konfigurations-
 gränssnitt. Du kan komma åt gränssnittet med vilken webbläsare som
 helst som stöder formulär (t.ex. Mozilla, Lynx, Links och Galeon).

Template: caudium/listen_on
Type: string
Default: 80
Description: What port should the server listen on?
 Caudium is currently configured to listen on port
 '${portno}' of every interface in your machine. It seems,
 however, that this port is already taken by some other
 application. Please specify a different port.
Description-sv: Vilken port ska servern lyssna på?
 Caudium är för tillfället konfigurerad för att lyssna på port
 '${portno}' på varje nätverksenhet i din dator. Det verkar
 dock som att den här porten redan är upptagen av något annat
 program. Vänligen ange en annan port.

Template: caudium/start_options
Type: multiselect
Choices: threads, debug, once, profile, fd-debug, keep-alive
Description: Select options that should be used on startup
 'threads' - use threads (if available); 
 'debug' - output debugging information while running; 
 'once' - run in foreground; 
 'profile' - store profiling information; 
 'fd-debug' - debug file descriptor usage
 'keep-alive' - keep connections alive
Description-sv: Välj de inställningar som ska användas från start
 "trådar" - Använd trådar (om möjligt)
 "avlusning" - Skriv ut avlusningsinformation under körning
 "förgrund" - Kör i förgrunden
 "profilering" - Spara profileringsinformation
 "fd-avlusning" - Avlusa användandet av filidentifierare
 "håll-vid-liv" - Håll anslutningar vid liv

Template: caudium/cfg_port_taken
Type: note
Description: Cannot bind to port.
 The port you have specified for Caudium configuration interface
 is unavailable. Please specify another port number - Caudium
 cannot function properly without binding its configuration 
 interface to a port on your system.
Description-sv: Kan inte binda porten.
 Porten du har valt för Caudiums konfigurationsgränssnitt är inte
 tillgänglig. Vänligen ange ett annat portnummer - Caudium fungerar
 inte ordentligt utan att binda konfigurationsgränssnittet till en
 port på ditt system.

Template: caudium/last_screen
Type: note
Description: Caudium configuration
 After your Caudium is installed and running, you should point your
 forms-capable browser to localhost:${cfgport} to further configure
 Caudium using its web-based configuration interface.
 .
 For more information about Caudium see the documents in the
 /usr/share/doc/caudium directory and make sure to visit
 http://caudium.net/, http://caudium.org/ and http://caudium.info/
Description-sv: Caudium-konfiguration
 När Caudium är installerat och är igång, bör du rikta din formulär-
 anpassade webbläsare till localhost:${cfgport} för vidare konfiguration
 av Caudium via dess webbaserade konfigurationsgränssnitt.
 .
 För mer information om Caudium, se dokumenten i katalogen
 /usr/share/doc/caudium. Besök också gärna http://caudium.net/,
 http://caudium.org/ och http://caudium.info/.

Template: caudium/experimental_http
Type: boolean
Default: false
Description: Use the experimental HTTP protocol module?
 Caudium comes with an experimental HTTP module that is faster than
 the original one. The code is still Work-In-Progress, so you might
 experience problems running it. It is NOT recommended to run this
 code on a production server. If, however, you want to test its 
 functionality, answer YES to this question.
Description-sv: Använd den experimentella HTTP-modulen?
 Caudium kommer med en experimentell HTTP-modul som är snabbare än
 den ursprungliga. Koden är fortfarande Pågående Arbete, så du kan
 få problem med den. Det rekommenderas INTE att köra den här modulen
 på en produktionsserver. Om du dock vill testa funktionaliteten,
 svara JA på den här frågan.
