Template: caudium/config_port
Type: string
Default: 22202
Description: On what port should the config interface be?
 Specify the port on which Caudium will provide its configuration
 interface. You can access the interface using any form capable
 web browser (like Mozilla, Lynx, Links or Galeon)
Description-pl: Numer portu interfejsu konfiguracyjnego?
 Podaj port, na którym serwer udostêpni swój interfejs konfiguracyjny.
 Interfejs jest osi±galny przez wpisanie adresu w dowolnej przegl±darce
 WWW, która obs³uguje formularze (np. Mozilla, Lynx, Links czy Galeon)

Template: caudium/listen_on
Type: string
Default: 80
Description: What port should the server listen on?
 Caudium is currently configured to listen on port
 '${portno}' of every interface in your machine. You can, however,
 specify a different port here if there's such need.
Description-pl: Na którym porcie serwer ma nas³uchiwaæ?
 Caudium jest w tej chwili skonfigurowany by oczekiwaæ na
 po³±czenia na porcie '${portno}' ka¿dego interfejsu w twoim
 komputerze. Mo¿esz jednak¿e podaæ inny numer portu poni¿ej, je¶li
 istnieje taka potrzeba.

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
Description-pl: Wybierz opcje startowe serwera
 'threads' - u¿yj w±tków (je¶li s± osi±galne)
 .
 'debug' - wy¶wietlaj dodatkowe informacje podczas pracy serwera
 .
 'once' - uruchom serwer w jednej kopii
 .
 'profile' - zapisz informacjê dot. profilowania serwera
 .
 'fd-debug' - wy¶wietlaj dodatkowe informacje o deskryptorach plików
 .
 'keep-alive' - stosuj opcjê 'keep alive' protoko³u HTTP/1.1

Template: caudium/cfg_port_taken
Type: note
Description: Cannot bind to port.
 The port you have specified for Caudium configuration interface
 is unavailable. Please specify another port number - Caudium
 cannot function properly without binding its configuration 
 interface to a port on your system.
Description-pl: Nie mo¿na otworzyæ portu
 Port podany dla interfejsu konfiguracyjnego jest nieosi±galny.
 Proszê podaæ inny numer portu - Caudium nie mo¿e funkcjonowaæ
 prawid³owo bez pod³±czenia interfejsu konfiguracyjnego do
 portu w twoim systemie.

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
 http://caudium.net/, http://caudium.org/ and http://caudium.info
Description-pl: Konfiguracja Caudium
 Po zainstalowaniu i uruchomieniu Caudium nale¿y niezw³ocznie otworzyæ
 w przegl±darce obs³uguj±cej formularze adres http://localhost:${cfgport}/
 aby dokoñczyæ konfiguracjê serwera przy u¿yciu interfejsu konfiguracyjnego.
 JEST TO NIEZMIERNIE WA¯NE gdy¿ ten krok zawiera tworzenie konta/has³a
 administracyjnego.
 .
 By uzyskaæ wiêcej informacji o Caudium proszê przeczytaæ dokumenty
 w katalogu /usr/share/doc/caudium i odwiedziæ strony http://caudium.net/,
 http://caudium.org/ oraz http://caudium.info/

Template: caudium/experimental_http
Type: boolean
Default: false
Description: Use the experimental HTTP protocol module?
 Caudium comes with an experimental HTTP module that is faster than
 the original one. The code is still Work-In-Progress, so you might
 experience problems running it. It is NOT recommended to run this
 code on a production server. If, however, you want to test its 
 functionality, answer YES to this question.
Description-pl: Czy u¿ywaæ experymentalnego modu³u HTTP?
 Caudium zawiera eksperymentalny modu³ HTTP, który jest znacznie
 szybszy od standardowego. Kod ten, jednak¿e, jest jeszcze w fazie
 testowania, tak wiêc mog± wyst±piæ niewielkie problemy przy jego
 u¿ywaniu. Nie zaleca siê u¿ywania tego modu³u na "¿ywym" serwerze.
 Je¶li, jednak¿e, chcesz przetestowac ten modu³ odpowiedz TAK na
 powy¿sze pytanie.

