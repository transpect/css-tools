<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:css="http://www.w3.org/1996/css"
  version="2.0" 
  exclude-result-prefixes="#all">
  
  <xsl:output method="text" media-type="text/plain" encoding="utf-8" indent="yes"/>
  
  <xsl:param name="cut-paths" select="'true'" as="xs:string"/>
  <xsl:param name="strip-comments" select="'false'" as="xs:string"/>
  <xsl:param name="newline" select="'&#xd;&#xa;'" as="xs:string"/>
  <xsl:param name="prepend-resource-path" select="''" as="xs:string"/><!-- '../' -->
  
  <xsl:template match="/css:css">
    <c:data content-type="text/plain">
      <xsl:attribute name="xml:base" select="(@xml:base, base-uri())[1]"/>
      <xsl:apply-templates select="*"/>
    </c:data>
  </xsl:template>
  
  <xsl:template match="text()[not(normalize-space())]"/>
  
  <xsl:template match="css:ruleset">
    <xsl:if test="not(css:selector/@raw-selector)">
      <xsl:message>No raw selector: <xsl:copy-of select="."/></xsl:message>
    </xsl:if>
    <xsl:variable name="css-selector" select="css:selector/@raw-selector" as="attribute(raw-selector)*"/>
    <xsl:variable name="css-properties" as="xs:string">
      <xsl:call-template name="declarations"/>
    </xsl:variable>
    <xsl:value-of select="string-join($css-selector, ', '), ' {', $css-properties, $newline, '}', $newline" separator=""/>
  </xsl:template>

  <!-- Might eventually consider re-serializing from the fine-grained parsed content -->
  <xsl:template match="css:atrule">
    <xsl:value-of select="css:raw-css, $newline" separator=""/>
  </xsl:template>

  <xsl:template match="css:comment[$strip-comments = 'false']">
    <xsl:value-of select="concat(., $newline)"/>
  </xsl:template>
  
  <xsl:template match="css:comment[$strip-comments = 'true']"/>

  <xsl:template name="declarations">
    <xsl:variable name="prelim" as="xs:string*">
      <xsl:apply-templates select="css:shorthand | css:declaration[not(@shorthand = ../css:shorthand/@num)]"/>
    </xsl:variable>
    <xsl:value-of select="concat($newline, '  ', string-join(for $p in $prelim return  concat($p, ';'), concat($newline, '  ')))"/>
  </xsl:template>
  
  <xsl:template match="css:declaration | css:shorthand">
    <xsl:variable name="prelim" as="xs:string+">
      <xsl:sequence select="string(@property)"/>
      <xsl:text>: </xsl:text>
      <xsl:apply-templates select="if (exists(css:resource)) then css:resource else @value, @important"/>
    </xsl:variable>
    <xsl:sequence select="string-join($prelim, '')"/>
  </xsl:template>
  
  <xsl:template match="@important"/>
  
  <xsl:template match="@important[. = 'yes']">
    <xsl:text> !important</xsl:text>
  </xsl:template>
  
  <xsl:template match="css:resource">
    <xsl:text>url('</xsl:text>
    <xsl:value-of select="$prepend-resource-path"/>
    <xsl:value-of select="(@local-src, @src)[1]"/>
    <xsl:text>')</xsl:text>
    <xsl:apply-templates select="@format"/>
    <xsl:if test="following-sibling::css:resource">
      <xsl:value-of select="concat(', ', $newline, '       ')"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="css:resource/@format">
    <xsl:text> format('</xsl:text>
    <xsl:value-of select="."/>
    <xsl:text>')</xsl:text>
  </xsl:template>
  
  <xsl:template match="@value">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="css:atrule[@type = ('font-face', 'page')]">
    <xsl:value-of select="concat('@', @type, ' {')"/>
    <xsl:call-template name="declarations"/>
    <xsl:sequence select="concat($newline, '}', $newline)"/>
  </xsl:template>

  <xsl:template match="css:raw-css"/>
  
</xsl:stylesheet>