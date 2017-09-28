<?xml version="1.0"?>
<p:library 
  xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:cx="http://xmlcalabash.com/ns/extensions" 
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:tr="http://transpect.io"
  xmlns:css="http://www.w3.org/1996/css" 
  version="1.0">

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
	<p:import href="http://transpect.io/xproc-util/file-uri/xpl/file-uri.xpl"/>
  <p:import href="http://transpect.io/xproc-util/simple-progress-msg/xpl/simple-progress-msg.xpl"/>
  
  <p:declare-step type="css:parse" name="parse">

    <p:documentation>In order to invoke this step directly with Calabash, you need to specify -l css-tools/xpl/css.xpl and
    -s {http://www.w3.org/1996/css}parse</p:documentation>

    <p:input port="source" primary="true">
      <p:documentation>an XHTML document</p:documentation>
    </p:input>
    <p:input port="stylesheet">
      <p:document href="../xsl/REx_css-parser.xsl"/>
      <p:documentation>a stylesheet that can be overridden, e.g. if CSS2.1 features are wanted only or if you want to use the 
        oldschool regex-based parser</p:documentation>
    </p:input>
    <p:output port="result" primary="true">
      <p:documentation>XML representation of the CSS. See css:expand</p:documentation>
    </p:output>
    <p:output port="report" sequence="true">
      <p:pipe port="report" step="apply-parsing-xsl"/>
    </p:output>
    
    <p:option name="debug" required="false" select="'no'"/>
    <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>
    <p:option name="status-dir-uri" required="false" select="resolve-uri('status')"/>
    <p:option name="remove-comments" select="'no'"/>

    <tr:file-uri name="base-uri">
      <p:documentation> Calculate base-uri </p:documentation>
      <p:with-option name="filename" select="(base-uri(/*), static-base-uri())[1]">
        <p:pipe port="source" step="parse"/>
      </p:with-option>
    </tr:file-uri>

    <p:try name="apply-parsing-xsl">
      <p:documentation>First try parsing with comments (unless $remove-comments='yes' anyway), 
        then try parsing without comments. Parsing with comments will fail if comments are located 
        in selectors or properties.
      We introduced the possibility to remove comments unconditionally (by setting the option 
      'remove-comments' to 'yes') because Calabash crashed in certain, poorly understood 
      circumstances with a null pointer exception instead of 
      catching the error.</p:documentation>
      <p:group>
        <p:output port="result" primary="true"/>
        <p:output port="report" sequence="true">
          <p:inline><c:ok/></p:inline>
        </p:output>
        <p:xslt name="apply-parsing-xsl-with-comments">
          <p:input port="parameters"><p:empty/></p:input>
          <p:input port="stylesheet">
            <p:pipe port="stylesheet" step="parse"/>
          </p:input>
          <p:input port="source">
            <p:pipe port="source" step="parse"/>
          </p:input>
          <p:with-param name="base-uri" select="/c:result/@local-href">
            <p:pipe port="result" step="base-uri"/>
          </p:with-param>
          <p:with-param name="remove-comments" select="$remove-comments"/>
        </p:xslt>
        <tr:store-debug pipeline-step="css-expand/css.1.parse-try">
          <p:with-option name="active" select="$debug"/>
          <p:with-option name="base-uri" select="$debug-dir-uri"/>
        </tr:store-debug>
      </p:group>
      <p:catch name="catch">
        <p:output port="result" primary="true"/>
        <p:output port="report" sequence="true">
          <p:pipe port="result" step="info"/>
        </p:output>

        <tr:propagate-caught-error name="propagate" msg-file="css-parsing-error.txt" code="tr:CSS01" severity="warning">
          <p:with-option name="status-dir-uri" select="$status-dir-uri"/>
          <p:input port="source">
            <p:pipe port="error" step="catch"/>
          </p:input>
        </tr:propagate-caught-error>
        
        <p:insert position="last-child" match="/c:errors" name="info">
          <p:input port="insertion">
            <p:inline>
              <c:error code="tr:CSS02" type="info">Reverting to CSS parsing with all comments removed. You can try to
              help the parser by moving comments from selectors and properties outside the rules.</c:error>
            </p:inline>
          </p:input>
        </p:insert>

        <p:sink/>

        <p:xslt name="apply-parsing-xsl-without-comments">
          <p:input port="parameters">
            <p:empty/>
          </p:input>
          <p:input port="stylesheet">
            <p:pipe port="stylesheet" step="parse"/>
          </p:input>
          <p:input port="source">
            <p:pipe port="source" step="parse"/>
          </p:input>
          <p:with-param name="base-uri" select="/c:result/@local-href">
            <p:pipe port="result" step="base-uri"/>
          </p:with-param>
          <p:with-param name="remove-comments" select="'yes'"/>
        </p:xslt>
      </p:catch>
    </p:try>
    
    <tr:store-debug pipeline-step="css-expand/css.1.parse">
      <p:with-option name="active" select="$debug"/>
      <p:with-option name="base-uri" select="$debug-dir-uri"/>
    </tr:store-debug>
    
    <p:xslt name="post-process" initial-mode="post-process">
      <p:input port="parameters"><p:empty/></p:input>
      <p:input port="stylesheet">
        <p:pipe port="stylesheet" step="parse"/>
      </p:input>
      <p:with-param name="base-uri" select="/c:result/@local-href">
        <p:pipe port="result" step="base-uri"/>
      </p:with-param>
    </p:xslt>
    
    <tr:store-debug pipeline-step="css-expand/css.2.xml-representation">
      <p:with-option name="active" select="$debug"/>
      <p:with-option name="base-uri" select="$debug-dir-uri"/>
    </tr:store-debug>
  </p:declare-step>
  
  
  <p:declare-step type="css:expand" name="expand">

    <p:input port="source" primary="true">
      <p:documentation>An XHTML document</p:documentation>
    </p:input>
    <p:input port="stylesheet">
      <p:document href="../xsl/REx_css-parser.xsl"/>
      <p:documentation>A parsing stylesheet that can be overriden. Use ../xsl/css2-1-parser.xsl for CSS 2.1 features and
      ../xsl/css-parser.xsl for the previous, regex-based parser.</p:documentation>
    </p:input>
    <p:output port="result" primary="true">
      <p:documentation>An XHTML document with CSSa attributes (in addition to its style elements/attributes/linked CSS
        stylesheets)</p:documentation>
    </p:output>
    <p:output port="xml-representation">
      <p:pipe step="parse" port="result">
        <p:documentation>There is currently no schema for the internal “CSS as XML” representation. We should use CSSa at some
          stage, but CSSa was developed after css:expand, and all of CSS may not (yet) fully expressed in
          CSSa.</p:documentation>
      </p:pipe>
    </p:output>
    <p:output port="report" sequence="true">
      <p:pipe port="report" step="parse"/>
    </p:output>

    <p:option name="path-constraint" required="false" select="''">
      <p:documentation>a predicate for matching only specific nodes, e.g., '[parent::*:tr]' for expanding only HTML table cell
        attributes</p:documentation>
    </p:option>
    <p:option name="prop-constraint" required="false" select="''">
      <p:documentation>space-separated list of property names that should be attached as css: attributes, e.g., 'width
        padding-top padding-bottom'</p:documentation>
    </p:option>
    <p:option name="debug" required="false" select="'no'"/>
    <p:option name="debug-dir-uri" required="false" select="resolve-uri('debug')"/>

    <css:parse name="parse">
      <p:input port="stylesheet">
        <p:pipe port="stylesheet" step="expand"/>
      </p:input>
      <p:with-option name="debug" select="$debug"/>
      <p:with-option name="debug-dir-uri" select="$debug-dir-uri"/>
    </css:parse>

    <p:xslt name="css-xsl">
      <p:input port="parameters">
        <p:empty/>
      </p:input>
      <p:with-param name="debug" select="$debug"/>
      <p:with-param name="path-constraint" select="$path-constraint"/>
      <p:with-param name="prop-constraint" select="$prop-constraint"/>
      <p:input port="stylesheet">
        <p:document href="../xsl/css2xsl.xsl"/>
      </p:input>
    </p:xslt>

    <tr:store-debug pipeline-step="css-expand/css.4.create-xsl" extension="xsl">
      <p:with-option name="active" select="$debug"/>
      <p:with-option name="base-uri" select="$debug-dir-uri"/>
    </tr:store-debug>

    <p:sink/>

    <p:xslt>
      <p:input port="source">
        <p:pipe step="expand" port="source"/>
      </p:input>
      <p:input port="parameters">
        <p:empty/>
      </p:input>
      <p:input port="stylesheet">
        <p:pipe step="css-xsl" port="result"/>
      </p:input>
    </p:xslt>

    <tr:store-debug pipeline-step="css-expand/css.5.expanded">
      <p:with-option name="active" select="$debug"/>
      <p:with-option name="base-uri" select="$debug-dir-uri"/>
    </tr:store-debug>

  </p:declare-step>
  
</p:library>