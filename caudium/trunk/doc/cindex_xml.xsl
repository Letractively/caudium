<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">
<!-- Caudium index XSLT stylesheet
-->
<xsl:output indent="yes" method="html" media-type="rxml:text/html" encoding="iso-8859-1"/>

<!-- Index for modules and files -->
<xsl:param name="display">files</xsl:param>

<xsl:template match="index">
  <xsl:text disable-output-escaping="yes">&lt;use file="/layout.tmpl"></xsl:text>
  <xsl:choose>
    <xsl:when test="$display = 'modules'">
      <page title="Caudium Module Index">
       <h3>List of all Caudium Modules</h3>
       <dl><xsl:apply-templates select='entry[@type="module"]' mode="top">
           <xsl:sort select="@name"/></xsl:apply-templates></dl>
       <xsl:comment>XSLT Template version $Id$</xsl:comment>
      </page>
    </xsl:when>

    <xsl:when test="$display = 'tags'">
      <page title="Caudium RXML Tags Index">
       <h3>Caudium RXML Tags Index</h3>
         <p><tablify wrap="1" nice='' cellseparator="/%%/" rowseparator="/@@/">Tag / Container/%%/In Module
         <xsl:apply-templates select='/descendant::entry[@type="tag" or @type="container"]' mode="top">
           <xsl:sort select="@name"/></xsl:apply-templates>
         </tablify></p>
       <xsl:comment>XSLT Template version $Id$</xsl:comment>
      </page>
    </xsl:when>

    <xsl:when test="$display = 'scopes'">
      <page title="Caudium Scope / Entity Index">
       <h3>Caudium Scope / Entity Index</h3>
         <p><tablify wrap="1" nice='' cellseparator="/%%/" rowseparator="/@@/">Entity /%%/ In Module
         <xsl:apply-templates select='/descendant::entry[@type="scope"]' mode="top">
           <xsl:sort select="@name"/></xsl:apply-templates>
         </tablify></p>
       <xsl:comment>XSLT Template version $Id$</xsl:comment>
      </page>
    </xsl:when>

<xsl:when test="$display = 'methods'">
      <page title="Caudium Method Index">
       <h3>Caudium Method Index</h3>
         <p><tablify wrap="1" nice='' cellseparator="/%%/" rowseparator="/@@/">Method/%%/Defined in...
         <xsl:apply-templates select='/descendant::entry[@type="method"]' mode="method">
           <xsl:sort select="@name"/></xsl:apply-templates>
         </tablify></p>
       <xsl:comment>XSLT Template version $Id$</xsl:comment>
      </page>
    </xsl:when>
    <xsl:otherwise>
      <page title="Caudium File / Method Index">
        This is an index of all documented files and methods. Please note
        that the documentation is far from complete. This reference 
	documentation is meant for programmers that want to make custom
	modules, Pike scripts or want to work on the webserver itself.
	<dl>
          <xsl:apply-templates select='entry[@type="file"]' mode="top">
		<xsl:sort select="@name"/>
	  </xsl:apply-templates>
       </dl>
       <xsl:comment>XSLT Template version $Id$</xsl:comment>
      </page>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="entry" mode="top">
  <xsl:choose>
   <xsl:when test="@type='file'">
    <dt><b><a href="{@path}">
     <xsl:choose>
     <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
     </xsl:choose>
    </a></b></dt>
    <dl><xsl:apply-templates select='entry[@type="method" or @type="class"]' mode="top"><xsl:sort select="@name"/></xsl:apply-templates></dl><br />
   </xsl:when>

   <xsl:when test="@type='module'">
    <dt><b><a href="{@path}">
     <xsl:choose>
     <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
     </xsl:choose>
    </a></b></dt>
   </xsl:when>

   <xsl:when test="@type='tag'">
    /@@/<a href="{@path}#{@name}">
     &lt;<xsl:value-of select="@name"/> /&gt;
    </a>/%%/<a href="{../@path}">
     <xsl:choose>
     <xsl:when test="../@title"><xsl:value-of select="../@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="../@name"/></xsl:otherwise>
     </xsl:choose></a>
   </xsl:when>

   <xsl:when test="@type='container'">
    /@@/<a href="{@path}#{@name}">
     &lt;<xsl:value-of select="@name"/>&gt;&lt;/<xsl:value-of select="@name"/>&gt;
    </a>/%%/<a href="{../@path}">
     <xsl:choose>
     <xsl:when test="../@title"><xsl:value-of select="../@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="../@name"/></xsl:otherwise>
     </xsl:choose></a>
   </xsl:when>

   <xsl:when test="@type='scope'">
    <xsl:if test='count(entry[@type="entity"]) = 0'>
      /@@/<a href="{@path}#{@name}">
       &amp;<xsl:value-of select="@name"/>;
      </a>/%%/<a href="{../@path}">
       <xsl:choose>
       <xsl:when test="../@title"><xsl:value-of select="../@title"/></xsl:when>
       <xsl:otherwise><xsl:value-of select="../@name"/></xsl:otherwise>
       </xsl:choose></a>
     </xsl:if>
     <xsl:apply-templates select='entry[@type="entity"]' mode="top"><xsl:sort select="@name"/></xsl:apply-templates>
   </xsl:when>

   <xsl:when test="@type='entity'">
    /@@/<a href="{@path}#{@name}">
     &amp;<xsl:value-of select="../@name"/>.<xsl:value-of select="@name"/>;
    </a>/%%/<a href="{../../@path}">
     <xsl:choose>
     <xsl:when test="../../@title"><xsl:value-of select="../../@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="../../@name"/></xsl:otherwise>
     </xsl:choose></a>
   </xsl:when>

   <xsl:when test="@type='tag'">
    /@@/<a href="{@path}#{@name}">
     &lt;<xsl:value-of select="@name"/> /&gt;
    </a>/%%/<a href="{../@path}">
     <xsl:choose>
     <xsl:when test="../@title"><xsl:value-of select="../@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="../@name"/></xsl:otherwise>
     </xsl:choose></a>
   </xsl:when>

   <xsl:otherwise>
    <dd><a href="{@path}#{@name}">
     <xsl:choose>
     <xsl:when test="@title"><xsl:value-of select="@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
     </xsl:choose>
    </a></dd>
    <dl><xsl:apply-templates select='entry[@type="method" or @type="class"]' mode="top"><xsl:sort select="@name"/></xsl:apply-templates></dl>
   </xsl:otherwise>   

  </xsl:choose> 
</xsl:template>

<xsl:template match="entry" mode="method">
  <xsl:choose>
   <xsl:when test="@type='method'">
    /@@/<a href="{@path}#{@name}">
     &lt;<xsl:value-of select="@name"/> /&gt;
    </a>/%%/<a href="{../@path}">
     <xsl:choose>
     <xsl:when test="../@title"><xsl:value-of select="../@title"/></xsl:when>
     <xsl:otherwise><xsl:value-of select="../@name"/></xsl:otherwise>
     </xsl:choose></a>
   </xsl:when>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
