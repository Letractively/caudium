
CLASSPATH = servlet.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

MODULEDIR = ../../modules

all : caudium_module.jar caudium_servlet.jar compile_modules

caudium_servlet.jar : servlet_classes
	jar cf $@ net/caudium/servlet/*.class

servlet_classes : $(SRCDIR)/net/caudium/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

caudium_module.jar : module_classes
	jar cf $@ net/caudium/caudium/*.class

module_classes : $(SRCDIR)/net/caudium/caudium/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

compile_modules: caudium_module.jar 
	CLASSPATH=caudium_module.jar find $(MODULEDIR) -name '*.java' \
		-exec $(JAVAC) $(JAVAFLAGS) {} \;
