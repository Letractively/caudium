Using Java Server Pages with Caudium
---------------------------------------
Caudium supports the Java Servlet 2.2 specification, which means that you 
can use Java Server Pages (JSP) with Caudium. Caudium includes the Jasper 
JSP Engine, which supports JSP 1.1. You can configure a Servlet module to 
use jasper for all files with a given extension (such as jsp).

To use JSP support, you will need a pike that supports Java (see 
pike --features for that). 

How to install and use:

1. Have a pike with java support running Caudium.
2. Create a JSP cache directory for your Virtual Server, such as 
     /path/to/caudium/var/virtual_server_name/jsp_cache
3. Properly set your JAVA_HOME environment variable.
4. Start Caudium and add the Java Servlet Bridge to a virtual server.
5. Set the following parameters in the Java Servlet Bridge module:

Class Name:             org.apache.jasper.servlet.JspServlet
Class Path:             etc/classes/jasper/commons-logging-api.jar, 
                        etc/classes/jasper/core_util.jar, 
                        etc/classes/jasper/jasper.jar, 
                        etc/classes/jasper/tomcat-util.jar
File extension servlet: Yes
Parameters:             sendErrToClient=false
                        scratchdir=path from step #2
                        mappedfile=false
                        largefile=false
                        keepgenerated=true
                        debug=false
                        classpath=the jar files listed in the Class 
                        Path setting option, separated by ":", plus any 
                        additional class path. 
                Example: file1.jar:file2.jar:etc/classes/jasper/jasper.jar
Servlet extensions:	jsp

6. Save the settings.
7. Copy a JSP file, such as HellowWorld.jsp below, to your virtual server.

<% String s="World"; %><html>
Hello<%= s %>
</html>

8. You should get a result like this when accessing this jsp file:

<html>
HelloWorld
</html>
