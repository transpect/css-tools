<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:css="http://www.w3.org/1996/css" 
  xmlns:tr="http://transpect.io"
  version="1.0"
  type="css:generate" 
  name="css-generate">
  
  <p:input port="source"/>
  
  <p:output port="result" primary="true"/>
  
  <p:option name="cut-paths" select="'false'"/>
  <p:option name="strip-comments" select="'false'"/>
  <p:option name="prepend-resource-path" select="''">
    <p:documentation>A common prefix path. Works only with relative URIs. If the generated CSS is in 
    a 'styles' subdir, add prepend-resource-path="../" in order to be able to access the linked resources.</p:documentation>
  </p:option>
  
  <p:option name="debug" required="false" select="'no'"/>
  <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>
  
  <p:serialization port="result" method="text" media-type="text/css" encoding="UTF-8"/>
  
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <p:xslt name="css-xml2plaintext">
    <p:with-param name="cut-paths" select="$cut-paths"/>
    <p:with-param name="strip-comments" select="$strip-comments"/>
    <p:with-param name="prepend-resource-path" select="$prepend-resource-path"/>
    <p:input port="stylesheet">
      <p:document href="../xsl/css-generate.xsl"/>
    </p:input>
  </p:xslt>
  
  <tr:store-debug pipeline-step="css-generate/generated-stylesheet">
    <p:with-option name="active" select="$debug" />
    <p:with-option name="base-uri" select="$debug-dir-uri" />
  </tr:store-debug>
  
</p:declare-step>