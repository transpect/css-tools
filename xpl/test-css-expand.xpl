<?xml version="1.0"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:css="http://www.w3.org/1996/css" 
  version="1.0"
  name="test-css-expand">

  <p:input port="source" primary="true">
    <p:documentation>an XHTML document</p:documentation>
  </p:input>
  <p:input port="stylesheet">
    <p:document href="../xsl/css-parser.xsl"/>
    <p:documentation>a stylesheet that can be overriden, e.g. if CSS2.1 features are wanted only</p:documentation>
  </p:input>
  <p:output port="result" primary="true">
    <p:documentation>an XHTML document with CSSa attributes (in addition to its style elements/attributes/linked CSS
      stylesheets)</p:documentation>
  </p:output>
  <p:output port="xml-representation">
    <p:pipe step="expand" port="xml-representation">
      <p:documentation>There is currently no schema for the internal “CSS as XML” representation. We should use CSSa at some
        stage, but CSSa was developed after css:expand, and all of CSS may not (yet) fully expressed in CSSa.</p:documentation>
    </p:pipe>
  </p:output>
  <p:serialization port="xml-representation" omit-xml-declaration="false" indent="true"/>

  <p:option name="path-constraint" required="false" select="''">
    <p:documentation>a predicate for matching only specific nodes, e.g., '[parent::*:tr]' for expanding only HTML table cell
      attributes</p:documentation>
  </p:option>
  <p:option name="prop-constraint" required="false" select="''">
    <p:documentation>space-separated list of property names that should be attached as css: attributes, e.g., 'width padding-top
      padding-bottom'</p:documentation>
  </p:option>
  <p:option name="debug" required="false" select="'no'"/>
  <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>

  <p:import href="css.xpl"/>

  <css:expand name="expand">
    <p:input port="stylesheet">
      <p:pipe port="stylesheet" step="test-css-expand"/>
    </p:input>
    <p:with-option name="path-constraint" select="$path-constraint"/>
    <p:with-option name="prop-constraint" select="$prop-constraint"/>
    <p:with-option name="debug" select="$debug"/>
    <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
  </css:expand>

</p:declare-step>
