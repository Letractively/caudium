<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- Caudium doc parsing XSLT stylesheet
     Very early version - don't expect any bells and whistles.
-->
<xsl:include href="file:/home/neotron/src/caudium/doc/base_html.xsl"/>
<xsl:output indent="yes" method="html" media-type="text/html" encoding="iso-8859-1"/>
<xsl:template match="documentation">
 <xsl:text disable-output-escaping="yes">&lt;use file="/layout.tmpl"></xsl:text>
<page title="Caudium Documentation">
  <dl><xsl:apply-templates select="module | file"/></dl>
  <xsl:comment>XSLT Template version $Id$</xsl:comment>
 </page>
</xsl:template>


<!-- Layout for modules -->

<xsl:template match="module">
  <dt><h2><xsl:value-of select="@name"/></h2></dt>
  <xsl:apply-templates select="description"/>
  <p><dd><xsl:apply-templates select="inherits"/></dd></p>
  <xsl:apply-templates select="type"/>
  <xsl:apply-templates select="version"/>
  <xsl:apply-templates select="defvars"/>
  <xsl:apply-templates select="tags | containers | entities"/>
</xsl:template>

<xsl:template match="inherits">
  <b>Inherits: </b> <xsl:value-of select="@link"/><br />
</xsl:template>
<xsl:template match="inherited">
  <b>Inherited by <a href="{@href}"><xsl:value-of select="@class"/></a></b><br />
</xsl:template>

<xsl:template match="description">
 <dd><xsl:apply-templates/></dd>
</xsl:template>

<xsl:template match="defvar">
  <p><dt><b><a name="{@name}"><xsl:value-of select="@short"/></a> (<xsl:value-of select="@type"/>)</b></dt>
  <dd><xsl:apply-templates/></dd></p>
</xsl:template>

<xsl:template match="defvars">
 <xsl:if test="count(defvar) > 0">
  <p><h3>Module Variables:</h3>
  <dl><xsl:apply-templates select="defvar"/></dl>
  </p>
 </xsl:if>
</xsl:template>

<xsl:template match="tags">
 <xsl:if test="count(tag) > 0">
  <p><h3>Tags defined in this module:</h3>
  <dl><xsl:apply-templates select="tag"/></dl>
  </p>
 </xsl:if>
</xsl:template>

<xsl:template match="containers">
 <xsl:if test="count(tag) > 0">
  <p><h3>Containers defined in this module:</h3>
  <dl><xsl:apply-templates select="tag"/></dl></p>
 </xsl:if>
</xsl:template>

<xsl:template match="entities">
 <xsl:if test="count(scope) > 0">
  <p><h3>Entity scopes defined in this module:</h3>
  <xsl:apply-templates select="scope"/></p>
 </xsl:if>
</xsl:template>

<xsl:template match="tag">
  <dt><b><a name="{@name}"><xsl:value-of select="@synopsis"/></a></b></dt>
  <xsl:apply-templates select="description" mode="tag"/>
  <xsl:apply-templates select="attributes"/>
<xsl:comment>  <xsl:apply-templates select="note"/></xsl:comment>
</xsl:template>

<xsl:template match="scope">
  <dl><dt><b><a name="{@name}">&amp;<xsl:value-of select="@name"/>;</a></b></dt>
  <xsl:apply-templates select="description" mode="tag"/>
  <xsl:apply-templates select="entity">
    <xsl:with-param name="scope"><xsl:value-of select="@name"/></xsl:with-param>
  </xsl:apply-templates>
  </dl><hr noshade="noshade" size="1"/>
</xsl:template>

<xsl:template match="entity">
<xsl:param name="scope"/>
<dl><p><dt><b><a name="{@name}">&amp;<xsl:value-of select="$scope"/>.<xsl:value-of select="@name"/>;</a></b></dt>
  <dd><xsl:apply-templates/></dd></p>
  </dl>
</xsl:template>

<xsl:template match="attributes">
 <xsl:if test="count(attribute) > 0">
  <dd><p><tablify wrap="1" nice='' cellseparator="/%/" rowseparator="/@/">Attribute/%/Description
   <xsl:for-each select="attribute">/@/
     <xsl:value-of select="@syntax"/>/%/
     <xsl:apply-templates/>
   </xsl:for-each>
  </tablify></p></dd>
</xsl:if>
</xsl:template>

<xsl:template match="description" mode="tag">
  <p><xsl:apply-templates/></p>
</xsl:template>

<xsl:template match="type">
  <dd><b>Module Type:</b><xsl:text> </xsl:text> <xsl:value-of select="."/></dd>
</xsl:template>

<!-- Layout for files (non-modules) -->

<xsl:template match="file">
  <dt><h2>File <xsl:value-of select="@name"/></h2></dt>
  <dd><p><xsl:value-of select="description"/></p></dd>
  <xsl:apply-templates select="inherits"/>
  <xsl:apply-templates select="version"/>
  <xsl:apply-templates select="defvars" mode="globvar"/>
  <xsl:apply-templates select="methods"/>
</xsl:template>

<xsl:template match="defvars" mode="globvar">
 <xsl:if test="count(defvar) > 0">
  <p><h3>Global Variables:</h3>
  <dl><xsl:apply-templates select="defvar"/></dl>
  </p>
 </xsl:if>
</xsl:template>

<xsl:template match="methods">
 <xsl:if test="count(method) > 0">
  <p><dl><dt><h3>Methods:</h3></dt>
  <dd><dl><xsl:apply-templates select="method"/></dl></dd></dl>
  </p>
 </xsl:if>
</xsl:template>

<xsl:template match="method">
  <a name="{@name}"><h3><xsl:value-of select="@name"/></h3></a>
  <dl><dt><p><b>Function</b></p></dt>
  <dd><p><xsl:value-of select="short"/></p></dd>
  <xsl:apply-templates select="syntax"/>
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
  <dt><p><b>Syntax</b></p></dt>
  <dd><p><xsl:value-of select="."/></p></dd>
</xsl:template>

<xsl:template match="description" mode="method">
  <xsl:param name="scope"/>
  <dt><p><b>Description</b></p></dt>
  <dd><p><xsl:value-of select="."/></p>
  <xsl:if test="$scope = 'private'"><p><b>This is an internal function for use in the
  Caudium core only.</b></p></xsl:if>
  </dd>
</xsl:template>


<!-- Shared templates -->

<xsl:template match="version">
  <dd><b>Version:</b><xsl:text> </xsl:text> <xsl:value-of select="."/></dd>
</xsl:template>



</xsl:stylesheet>


