
CLASSDIR= ../../../server/etc/classes

CLASSPATH = ${CLASSDIR}/servlet.jar:${CLASSDIR}/lucene-1.2.jar

JAVAFLAGS = -deprecation -encoding iso-8859-1

JAVAC = javac

SRCDIR = ../src

MODULEDIR = ../../modules

JARS = caudium_module.jar caudium_servlet.jar caudium_search.jar

all : ${JARS}
	rm -rf net
	cp *.jar ../../../server/etc/classes

caudium_servlet.jar : servlet_classes
	@echo "making caudium_servlet.jar"
	jar cf $@ net/caudium/servlet/*.class

caudium_search.jar : search_classes
	@echo "making caudium_search.jar"
	jar cf $@ net/caudium/search/*.class

servlet_classes : $(SRCDIR)/net/caudium/servlet/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

search_classes : $(SRCDIR)/net/caudium/search/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

caudium_module.jar : module_classes
	@echo "making caudium_module.jar"
	jar cf $@ net/caudium/caudium/*.class

module_classes : $(SRCDIR)/net/caudium/caudium/*.java
	CLASSPATH=$(CLASSPATH) $(JAVAC) $(JAVAFLAGS) $^ -d .

clean:
	rm -f ${JARS}

#compile_modules: caudium_module.jar 
#	CLASSPATH=caudium_module.jar find $(MODULEDIR) -name '*.java' \
#		-exec $(JAVAC) $(JAVAFLAGS) {} \;
