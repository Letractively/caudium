Template: caudium/config_port
Type: string
Default: 22202
Description: On what port should the config interface be?
 Specify the port on which Caudium will provide its configuration
 interface. You can access the interface using any form capable
 web browser (like Mozilla, Lynx, Links or Galeon)
Description-pl: Numer portu interfejsu konfiguracyjnego?
 Podaj port, na kt�rym serwer udost�pni sw�j interfejs konfiguracyjny.
 Interfejs jest osi�galny przez wpisanie adresu w dowolnej przegl�darce
 WWW, kt�ra obs�uguje formularze (np. Mozilla, Lynx, Links czy Galeon)

Template: caudium/listen_on
Type: string
Default: 80
Description: What port should the server listen on?
 Caudium is currently configured to listen on port
 '${portno}' of every interface in your machine. You can, however,
 specify a different port here if there's such need.
Description-pl: Na kt�rym porcie serwer ma nas�uchiwa�?
 Caudium jest w tej chwili skonfigurowany by oczekiwa� na
 po��czenia na porcie '${portno}' ka�dego interfejsu w twoim
 komputerze. Mo�esz jednak�e poda� inny numer portu poni�ej, je�li
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
 'threads' - u�yj w�tk�w (je�li s� osi�galne)
 .
 'debug' - wy�wietlaj dodatkowe informacje podczas pracy serwera
 .
 'once' - uruchom serwer w jednej kopii
 .
 'profile' - zapisz informacj� dot. profilowania serwera
 .
 'fd-debug' - wy�wietlaj dodatkowe informacje o deskryptorach plik�w
 .
 'keep-alive' - stosuj opcj� 'keep alive' protoko�u HTTP/1.1

Template: caudium/cfg_port_taken
Type: note
Description: Cannot bind to port.
 The port you have specified for Caudium configuration interface
 is unavailable. Please specify another port number - Caudium
 cannot function properly without binding its configuration 
 interface to a port on your system.
Description-pl: Nie mo�na otworzy� portu
 Port podany dla interfejsu konfiguracyjnego jest nieosi�galny.
 Prosz� poda� inny numer portu - Caudium nie mo�e funkcjonowa�
 prawid�owo bez pod��czenia interfejsu konfiguracyjnego do
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
 http://caudium.net/.
Description-pl: Konfiguracja Caudium
 Po zainstalowaniu i uruchomieniu Caudium nale�y niezw�ocznie otworzy�
 w przegl�darce obs�uguj�cej formularze adres http://localhost:${cfgport}/
 aby doko�czy� konfiguracj� serwera przy u�yciu interfejsu konfiguracyjnego.
 JEST TO NIEZMIERNIE WA�NE gdy� ten krok zawiera tworzenie konta/has�a
 administracyjnego.
 .
 By uzyska� wi�cej informacji o Caudium prosz� przeczyta� dokumenty
 w katalogu /usr/share/doc/caudium i odwiedzi� strony http://caudium.net/

Template: caudium/experimental_http
Type: boolean
Default: false
Description: Use the experimental HTTP protocol module?
 Caudium comes with an experimental HTTP module that is faster than
 the original one. The code is still Work-In-Progress, so you might
 experience problems running it. It is NOT recommended to run this
 code on a production server. If, however, you want to test its 
 functionality, answer YES to this question.
Description-pl: Czy u�ywa� experymentalnego modu�u HTTP?
 Caudium zawiera eksperymentalny modu� HTTP, kt�ry jest znacznie
 szybszy od standardowego. Kod ten, jednak�e, jest jeszcze w fazie
 testowania, tak wi�c mog� wyst�pi� niewielkie problemy przy jego
 u�ywaniu. Nie zaleca si� u�ywania tego modu�u na "�ywym" serwerze.
 Je�li, jednak�e, chcesz przetestowac ten modu� odpowiedz TAK na
 powy�sze pytanie.

Template: caudium/config_login
Type: string
Default: admin
Description: Configuration interface login.
 This is the user login name for the configuration interface access.
 If you don't specify anything here, anybody who will access the
 config interface first will be able to set the login/password and
 manage your server. This is probably not what you want. Please
 specify the login name below or accept the default value.
Description-pl: Login do interfejsu konfiguracyjnego.
 Nazwa u�ytkownika wykorzystywana przy logowaniu si� do interfejsu
 konfiguracyjnego. Je�li nie podasz niczego w polu poni�ej ka�da 
 osoba, kt�ra otworzy stron� interfejsu konfiguracyjnego jako 
 pierwsza, b�dzie mog�a ustawi� login/has�o i przej�� kontrol�
 nad zarz�dzaniem serwerem. Prawdopodobnie nie jest to twoim zamiarem.
 Prosz� poda� login w polu poni�ej, lub zaakceptowa� domy�ln� warto��.

Template: caudium/config_password
Type: password
Default: password
Description: Configuration interface password
 This is the password used to access the configuration interface. The
 default value for it is 'password' - it is HIGHLY RECOMMENDED to
 change the default below!
Description-pl: Has�o dost�pu do interfejsu konfiguracyjnego.
 Has�o dost�pu do interfejsu konfiguracyjnego. Domy�ln� warto�ci�
 has�a jest 'password' - ZALECA si� zmian� domy�lnej warto�ci!

