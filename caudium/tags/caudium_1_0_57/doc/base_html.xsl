<?xml version="1.0"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- HTML type elements.. -->


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
<xsl:template match="ol">
 <ol><xsl:apply-templates/></ol>
</xsl:template>

<xsl:template match="b | strong">
 <b><xsl:apply-templates/></b>
</xsl:template>

<xsl:template match="em | i">
 <i><xsl:apply-templates/></i>
</xsl:template>
<xsl:template match="tt">
 <tt><xsl:apply-templates/></tt>
</xsl:template>
</xsl:stylesheet>


