<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- Caudium index XSLT stylesheet
-->
<xsl:output indent="yes" method="html" media-type="text/html" encoding="iso-8859-1"/>

<xsl:template match="index">
 <xsl:text disable-output-escaping="yes">&lt;use file="/layout.tmpl"></xsl:text>
 <page title="Caudium Module Index">
  <h3>List of all Caudium Modules</h3>
  <dl><xsl:apply-templates select='entry[@type="module"]' mode="top"><xsl:sort select="@name"/></xsl:apply-templates></dl>
  <xsl:comment>XSLT Template version $Id$</xsl:comment>
 </page>
</xsl:template>


<!-- Index for modules and files -->

<xsl:template match="entry" mode="top">
  <dt><b><a href="{@path}">
	<xsl:choose>
         <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
         <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
        </xsl:choose>
      </a></b></dt>
  <dd></dd>
</xsl:template>

<xsl:template match="tag">
  <dl><dt><h3><xsl:value-of select="@name"/> </h3></dt>
  <xsl:apply-templates select="description" mode="tag"/>
  <xsl:apply-templates select="attributes"/>
  <xsl:apply-templates select="returns"/>
  </dl><hr noshade="" size="1"/>
</xsl:template>

<xsl:template match="attributes">
  <dt><p><b>Attributes</b></p></dt>
  <dd><p><tablify wrap="1" nice="" cellseparator="%" rowseparator="@">Attribute%Default%Description
   <xsl:for-each select="attribute">@
     <xsl:value-of select="name"/>%
     <xsl:value-of select="default"/>%
     <xsl:value-of select="description"/>
   </xsl:for-each>
  </tablify></p></dd>
</xsl:template>

<xsl:template match="description" mode="tag">
  <dt><p><b>Description</b></p></dt>
  <dd><p><xsl:value-of select="."/></p>
  </dd>
</xsl:template>

<!-- Layout for files (non-modules) -->

<xsl:template match="file">
  <dt><h2>File <xsl:value-of select="@name"/></h2></dt>
  <dd><p><xsl:value-of select="description"/></p></dd>
  <xsl:apply-templates select="version"/>
  <dd><hr noshade="" size="1"/></dd>
  <dd><xsl:apply-templates select="method"/></dd>
</xsl:template>

<xsl:template match="method">
  <h3><xsl:value-of select="@name"/> </h3>
  <dl><dt><p><b>Function</b></p></dt>
  <dd><p><xsl:value-of select="short"/></p></dd>
  <xsl:apply-templates select="syntax"/>
  <xsl:apply-templates select="description" mode="method">
    <xsl:with-param name="scope"><xsl:value-of select="scope"/></xsl:with-param>
  </xsl:apply-templates>
  <xsl:apply-templates select="arguments"/>
  <xsl:apply-templates select="returns"/>
  </dl><hr noshade="" size="1"/>
</xsl:template>

<xsl:template match="arguments">
  <dt><p><b>Arguments</b></p></dt>
  <dd><p><tablify wrap="1" nice="" cellseparator="%" rowseparator="@">Argument%Description
   <xsl:for-each select="argument">@
     <xsl:value-of select="syntax"/>%
     <xsl:value-of select="description"/>
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
  <dd><dl><dt><p><h4>Version</h4></p></dt>
  <dd><xsl:value-of select="."/></dd></dl></dd>
</xsl:template>



</xsl:stylesheet>
