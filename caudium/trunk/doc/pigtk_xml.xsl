<?xml version="1.0"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- PiGTK docs XSLT layout file.
-->
<xsl:output indent="yes" method="html" media-type="text/html" encoding="iso-8859-1"/>
<xsl:template match="class">
  <html>
   <head><title>PiGTK Documentation: <xsl:value-of select="@name"/></title></head>
   <body>
    <dl>
     <dt><h1><xsl:value-of select="@name"/></h1></dt>
     <xsl:apply-templates select="doc"/>
     <p><dt><xsl:apply-templates select="inherit"/></dt></p>
     <p><dt><xsl:apply-templates select="inherited"/></dt></p>
     <xsl:apply-templates select="methods"/>
     <xsl:apply-templates select="signals"/>
    </dl>
   </body>
  </html>
</xsl:template>


<xsl:template match="inherit">
  <b>Inherits <a href="{@href}"><xsl:value-of select="@class"/></a></b><br />
</xsl:template>
<xsl:template match="inherited">
  <b>Inherited by <a href="{@href}"><xsl:value-of select="@class"/></a></b><br />
</xsl:template>

<xsl:template match="methods">
  <dt><h2>Methods</h2></dt>
  <dd><dl>
    <xsl:apply-templates select="method"/>
  </dl></dd>
  <xsl:apply-templates select="inherited-methods"/>
</xsl:template>

<xsl:template match="inherited-methods">
 <xsl:if test="count(method) > 0">
  <dt><h2>Inherited Methods</h2></dt>
  <dd><dl>
    <xsl:apply-templates select="method"/>
  </dl></dd>
 </xsl:if>
</xsl:template>

<xsl:template match="signal">
 <dt><b><xsl:value-of select="@name"/></b></dt>
 <xsl:apply-templates select="doc"/>
</xsl:template>

<xsl:template match="example">
  <br /><tt><xsl:value-of select="."/></tt>
</xsl:template>

<xsl:template match="p">
 <p><xsl:apply-templates/></p>
</xsl:template>

<xsl:template match="br">
 <br><xsl:apply-templates/></br>
</xsl:template>

<xsl:template match="table">
 <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="pre">
 <pre><xsl:apply-templates/></pre>
</xsl:template>

<xsl:template match="img">
 <br /><tt><xsl:copy-of select="."/></tt>
</xsl:template>

<xsl:template match="box">
 <dd><table><tr><td bgcolor="white"><xsl:apply-templates/></td></tr></table></dd>
</xsl:template>

<xsl:template match="doc">
 <dd><xsl:apply-templates/></dd>
</xsl:template>

<xsl:template match="li">
 <li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="dd | dt">
 <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="dl">
 <dl><xsl:apply-templates/></dl>
</xsl:template>

<xsl:template match="ul">
 <ul><xsl:apply-templates/></ul>
</xsl:template>

<xsl:template match="signals">
  <dt><h2>Signals</h2></dt>
  <dd><dl>
    <xsl:apply-templates select="signal"/>
  </dl></dd>
  <xsl:apply-templates select="inherited-signals"/>
</xsl:template>

<xsl:template match="inherited-signals">
  <xsl:if test="count(signal) > 0">
   <dt><h2>Inherited Signals</h2></dt>
   <dd><dl>
   <xsl:apply-templates select="signal"/>
   </dl></dd>
  </xsl:if>
</xsl:template>

<xsl:template match="constructor">
  <dt><h2>Constructor</h2></dt>
  <dd><dl>
    <xsl:apply-templates select="method"/>
  </dl></dd>
</xsl:template>


<xsl:template match="method">
 <dt>
  <b>
   <xsl:value-of disable-output-escaping="yes" select="@returns"/>
   <xsl:value-of select="@name"/> ( <xsl:for-each
     select="arg"><xsl:value-of select="@type"/><xsl:text> </xsl:text>
     <xsl:value-of select="@name"/><xsl:if test="position() != last()">, </xsl:if></xsl:for-each> )</b></dt>
     <xsl:text>&#xa;</xsl:text>
 <xsl:apply-templates select="doc"/>
</xsl:template>

</xsl:stylesheet>
