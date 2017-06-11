<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xslout="bogo"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tr="http://transpect.io"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:css="http://www.w3.org/1996/css"
  version="2.0"
  exclude-result-prefixes="xs">
  
  <!-- Overrides for CSS Parser. Expecially for EPUBs. 
    For example text-decoration should become a short hand property
    -->

  <xsl:import href="REx_css-parser.xsl"/>
  
  <!-- This variable is only there to eliminate the text-decoration property from the $prop list -->
  <xsl:variable name="css-shorthand-properties" select="('background', 'border', 'border-left', 'border-right', 
    'border-top', 'border-bottom', 'font', 'list-style', 'margin', 'padding')" as="xs:string+" />
  
</xsl:stylesheet>