Template: caudium/config_port
Type: string
Default: 22202
Description: On what port should the config interface be?
 Specify the port on which Caudium will provide its configuration
 interface. You can access the interface using any form capable
 web browser (like Mozilla, Lynx, Links or Galeon)
Description-sv: P� vilken port skall konfigurationsgr�nssnittet vara?
 Ange vilken port som Caudium skall tillhandah�lla sitt konfigurations-
 gr�nssnitt. Du kan komma �t gr�nssnittet med vilken webbl�sare som
 helst som st�der formul�r (t.ex. Mozilla, Lynx, Links och Galeon).

Template: caudium/listen_on
Type: string
Default: 80
Description: What port should the server listen on?
 Caudium is currently configured to listen on port
 '${portno}' of every interface in your machine. You can, however,
 specify a different port here if there's such need.
Description-sv: Vilken port ska servern lyssna p�?
 Caudium �r f�r tillf�llet konfigurerad f�r att lyssna p� port
 '${portno}' p� varje n�tverksenhet i din dator. Det verkar
 dock som att den h�r porten redan �r upptagen av n�got annat
 program. V�nligen ange en annan port.

Template: caudium/start_options
Type: multiselect
Choices: threads, debug, once, profile, fd-debug, keep-alive
Default: threads
Description: Select options that should be used on startup
 'threads' - use threads (if available)
 .
 'debug' - output debugging information while running
 .
 'once' - run in foreground
 .
 'profile' - store profiling information
 .
 'fd-debug' - debug file descriptor usage
 .
 'keep-alive' - keep connections alive with HTTP/1.1
Description-sv: V�lj de inst�llningar som ska anv�ndas fr�n start
 "tr�dar" - Anv�nd tr�dar (om m�jligt)
 .
 "avlusning" - Skriv ut avlusningsinformation under k�rning
 .
 "f�rgrund" - K�r i f�rgrunden
 .
 "profilering" - Spara profileringsinformation
 .
 "fd-avlusning" - Avlusa anv�ndandet av filidentifierare
 .
 "h�ll-vid-liv" - H�ll anslutningar vid liv

Template: caudium/cfg_port_taken
Type: note
Description: Cannot bind to port.
 The port you have specified for Caudium configuration interface
 is unavailable. Please specify another port number - Caudium
 cannot function properly without binding its configuration 
 interface to a port on your system.
Description-sv: Kan inte binda porten.
 Porten du har valt f�r Caudiums konfigurationsgr�nssnitt �r inte
 tillg�nglig. V�nligen ange ett annat portnummer - Caudium fungerar
 inte ordentligt utan att binda konfigurationsgr�nssnittet till en
 port p� ditt system.

Template: caudium/last_screen
Type: note
Description: Caudium configuration
 After your Caudium is installed and running, you should point your
 forms-capable browser to http://localhost:${cfgport} to further configure
 Caudium using its web-based configuration interface. THIS IS VERY
 IMPORTANT since that step involves creation of administrative
 login/password.
 .
 For more information about Caudium see the documents in the
 /usr/share/doc/caudium directory and make sure to visit
 http://caudium.net/
Description-sv: Caudium-konfiguration
 N�r Caudium �r installerat och �r ig�ng, b�r du rikta din formul�r-
 anpassade webbl�sare till http://localhost:${cfgport} f�r vidare konfiguration
 av Caudium via dess webbaserade konfigurationsgr�nssnitt.
 .
 F�r mer information om Caudium, se dokumenten i katalogen
 /usr/share/doc/caudium. Bes�k ocks� g�rna http://caudium.net/.

Template: caudium/experimental_http
Type: boolean
Default: false
Description: Use the experimental HTTP protocol module?
 Caudium comes with an experimental HTTP module that is faster than
 the original one. The code is still Work-In-Progress, so you might
 experience problems running it. It is NOT recommended to run this
 code on a production server. If, however, you want to test its 
 functionality, answer YES to this question.
Description-sv: Anv�nd den experimentella HTTP-modulen?
 Caudium kommer med en experimentell HTTP-modul som �r snabbare �n
 den ursprungliga. Koden �r fortfarande P�g�ende Arbete, s� du kan
 f� problem med den. Det rekommenderas INTE att k�ra den h�r modulen
 p� en produktionsserver. Om du dock vill testa funktionaliteten,
 svara JA p� den h�r fr�gan.

Template: caudium/config_login
Type: string
Default: admin
Description: Configuration interface login.
 This is the user login name for the configuration interface access.
 If you don't specify anything here, anybody who will access the
 config interface first will be able to set the login/password and
 manage your server. This is probably not what you want. Please
 specify the login name below or accept the default value.

Template: caudium/config_password
Type: password
Default: password
Description: Configuration interface password
 This is the password used to access the configuration interface. The
 default value for it is 'password' - it is HIGHLY RECOMMENDED to
 change the default below!
