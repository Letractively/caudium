<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- Caudium doc parsing XSLT stylesheet
     Very early version - don't expect any bells and whistles.
-->
<xsl:include href="base_html.xsl"/>
<xsl:output indent="yes" method="html" media-type="rxml:text/html" encoding="iso-8859-1"/>
<xsl:template match="documentation">
 <xsl:text disable-output-escaping="yes">&lt;use file="/caudium.tmpl"></xsl:text>
<page title="Caudium Documentation">
  <dl><xsl:apply-templates select="module | file"/></dl>
  <xsl:comment>XSLT Template version $Id$</xsl:comment>
 </page>
</xsl:template>


<!-- Layout for modules -->

<xsl:template match="module">
  <sub title="{@name}">
  <xsl:apply-templates select="description"/>
  <br />
  <xsl:apply-templates select="inherits">
  <xsl:sort select="@link"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="type"/>
  <xsl:apply-templates select="version"/>
  <xsl:apply-templates select="defvars"><xsl:sort select='@name'/></xsl:apply-templates>
  <xsl:apply-templates select="methods | tags | containers | entities"/>
  </sub>
</xsl:template>

<xsl:template match="inherits">
  <b>Inherits: </b> <xsl:value-of select="@link"/><br />
</xsl:template>
<xsl:template match="inherited">
  <b>Inherited by <a href="{@href}"><xsl:value-of select="@class"/></a></b><br />
</xsl:template>

<xsl:template match="description">
 <xsl:apply-templates/>
</xsl:template>

<xsl:template match="defvar">
  <b><a name="{@name}"><xsl:value-of select="@short"/></a> (<xsl:value-of select="@type"/>)</b><br />
  <xsl:apply-templates/><br /><br />
</xsl:template>

<xsl:template match="defvars">
 <xsl:if test="count(defvar) > 0">
  <br />
  <dlu title="Module Variables:">
  <xsl:apply-templates select="defvar"><xsl:sort select="@short"/></xsl:apply-templates>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="tags">
 <xsl:if test="count(tag) > 0">
  <br />
  <dlu title="Tags defined in this module:">
  <xsl:apply-templates select="tag"><xsl:sort select="@name"/></xsl:apply-templates>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="containers">
 <xsl:if test="count(tag) > 0">
  <br />
  <dlu title="Containers defined in this module:">
  <xsl:apply-templates select="tag"><xsl:sort select="@name"/></xsl:apply-templates>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="entities">
 <xsl:if test="count(scope) > 0">
  <br />
  <dlu title="Entity scopes defined in this module:">
  <xsl:apply-templates select="scope"><xsl:sort select="@name"/></xsl:apply-templates>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="tag">
  <b><a name="{@name}"><xsl:value-of select="@synopsis"/></a></b><br />
  <xsl:apply-templates select="description" mode="tag"/>
  <xsl:apply-templates select="attributes"/>
<xsl:comment>  <xsl:apply-templates select="note"/></xsl:comment>
  <br />
</xsl:template>

<xsl:template match="scope">
  <b><a name="{@name}">&amp;<xsl:value-of select="@name"/>;</a></b><br />
  <xsl:apply-templates select="description" mode="tag"/>
  <xsl:apply-templates select="entity">
    <xsl:sort select="@name"/>
    <xsl:with-param name="scope"><xsl:value-of select="@name"/></xsl:with-param>
  </xsl:apply-templates>
  <br />
</xsl:template>

<xsl:template match="entity">
<xsl:param name="scope"/>
 <b><a name="{@name}">&amp;<xsl:value-of select="$scope"/>.<xsl:value-of select="@name"/>;</a></b><br/>
  <xsl:apply-templates/>
  <br />
</xsl:template>

<xsl:template match="attributes">
 <xsl:if test="count(attribute) > 0">
  <br />
  <tablify wrap="1" nice='' cellseparator="/%/" rowseparator="/@/">Attribute/%/Description
   <xsl:for-each select="attribute">/@/
     <xsl:value-of select="@syntax"/>/%/
     <xsl:apply-templates/>
   </xsl:for-each>
  </tablify>
  <br />
</xsl:if>
</xsl:template>

<xsl:template match="description" mode="tag">
  <xsl:apply-templates/><br />
</xsl:template>

<xsl:template match="type">
  <b>Module Type:</b><xsl:text> </xsl:text> <xsl:value-of select="."/><br />
</xsl:template>

<!-- Layout for files (non-modules) -->

<xsl:template match="file">
  <h2>File <xsl:value-of select="@name"/></h2><br />
  <xsl:value-of select="description"/><br />
  <xsl:apply-templates select="inherits"/>
  <xsl:apply-templates select="version"/>
  <xsl:apply-templates select="classes"/>
  <xsl:apply-templates select="defvars" mode="globvar"/>
  <xsl:apply-templates select="methods"/>
</xsl:template>

<xsl:template match="defvars" mode="globvar">
 <xsl:if test="count(defvar) > 0">
  <br />
  <dlu title="Global Variables:">
  <xsl:apply-templates select="defvar"/>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="classes">
 <xsl:if test="count(class) > 0">
  <xsl:apply-templates select="class"/>
  <br />
 </xsl:if>
</xsl:template>

<xsl:template match="methods">
 <xsl:if test="count(method) > 0">
  <br />
  <dlu title="Methods:">
  <xsl:apply-templates select="method"/>
  </dlu>
 </xsl:if>
</xsl:template>

<xsl:template match="class">
  <a name="{@name}"><h3>Class <xsl:value-of select="@name"/></h3></a>
  <xsl:apply-templates select="description" mode="class">
    <xsl:with-param name="scope"><xsl:value-of select="scope"/></xsl:with-param>
  </xsl:apply-templates>
  <xsl:apply-templates select="methods"/>
</xsl:template>

<xsl:template match="method">
  <a name="{@name}"><h4><xsl:apply-templates select="syntax"/></h4></a>
  <dl><dt><p><b>Function</b></p></dt>
  <dd><p><xsl:value-of select="short"/></p></dd>

  <xsl:apply-templates select="description" mode="method">
    <xsl:with-param name="scope"><xsl:value-of select="scope"/></xsl:with-param>
  </xsl:apply-templates>
  <xsl:apply-templates select="arguments"/>
  <xsl:apply-templates select="returns"/>
  </dl>
</xsl:template>

<xsl:template match="arguments">
  <dt><p><b>Arguments</b></p></dt>
  <dd><p><tablify wrap="1" nice="" cellseparator="/%/" rowseparator="/@/">Argument/%/Description
   <xsl:for-each select="argument">/@/
     <xsl:value-of select="@syntax"/>/%/
     <xsl:apply-templates/>
   </xsl:for-each>
  </tablify></p></dd>
</xsl:template>

<xsl:template match="returns">
  <dt><p><b>Returns</b></p></dt>
  <dd><p><xsl:value-of select="."/></p></dd>
</xsl:template>

<xsl:template match="syntax">
  <xsl:value-of select="."/>
</xsl:template>

<xsl:template match="description" mode="method">
  <xsl:param name="scope"/>
  <dt><p><b>Description</b></p></dt>
  <dd><p><xsl:value-of select="."/></p>
  <xsl:if test="$scope = 'private'"><p><b>This is an internal function for use in the
  Caudium core only.</b></p></xsl:if>
  </dd>
</xsl:template>

<xsl:template match="description" mode="class">
  <xsl:param name="scope"/>
  <p><xsl:value-of select="."/></p>
  <xsl:if test="$scope = 'private'"><p><b>This is an internal function for use in the
  Caudium core only.</b></p></xsl:if>
</xsl:template>


<!-- Shared templates -->

<xsl:template match="version">
  <b>Version:</b><xsl:text> </xsl:text> <xsl:value-of select="."/><br />
</xsl:template>



</xsl:stylesheet>


