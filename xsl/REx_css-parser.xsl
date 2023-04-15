<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xslout="bogo"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tr="http://transpect.io"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:css="http://www.w3.org/1996/css"
  xmlns:p="CSS3"
  version="2.0"
  exclude-result-prefixes="xs"
  xmlns="http://www.w3.org/1996/css">

  <xsl:import href="css-util.xsl"/>
  <xsl:import href="CSS3.xsl"/>
  
  <xsl:output indent="yes" />

  <xsl:param name="base-uri" select="base-uri(/*)" as="xs:string" />
  <xsl:param name="remove-comments" select="'yes'" as="xs:string" />
  
  <xsl:template match="/">
    <parser-results xmlns="">
      <xsl:choose>
        <xsl:when test="matches(base-uri(/*), '^file:/')">
          <xsl:attribute name="xml:base" select="base-uri(/*)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'Spurious base URI: ', base-uri(/*)"/>      
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates mode="extract-css"
        select="/processing-instruction(xml-stylesheet)[matches(., 'type\s*=\s*.text/css')]
                union html:html/html:head/(html:link[@type = 'text/css' or @rel = 'stylesheet'] 
                union html:style)"/>
    </parser-results>
  </xsl:template>

  <xsl:template match="processing-instruction(xml-stylesheet)" mode="extract-css">
    <xsl:variable name="href" as="xs:string">
      <xsl:analyze-string select="." regex="href\s*=\s*[&apos;&quot;]([^&apos;&quot;]+)[&apos;&quot;]" flags="s">
        <xsl:matching-substring>
          <xsl:sequence select="regex-group(1)"/>
        </xsl:matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:variable name="external-css" as="xs:string?" select="tr:resolve-css-file-content($href, $base-uri)"/>
    <xsl:sequence select="tr:extract-css($external-css, $href, $remove-comments = 'yes')/css"></xsl:sequence>
  </xsl:template>

  <xsl:function name="tr:external-css-file-available" as="xs:boolean">
    <xsl:param name="href-attr-or-css-url-value" as="xs:string"/>
    <xsl:param name="baseuri" as="xs:string"/>
    <xsl:variable name="resolved" as="xs:anyURI"
      select="resolve-uri($href-attr-or-css-url-value, $baseuri)"/>
    <xsl:choose>
      <xsl:when test="unparsed-text-available($resolved, 'UTF-8')">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:when test="unparsed-text-available($resolved, 'CP1252')">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="tr:resolve-css-file-content" as="xs:string?">
    <xsl:param name="href-attr-or-css-url-value" as="xs:string"/>
    <xsl:param name="baseuri" as="xs:string"/>
    <xsl:variable name="resolved" as="xs:anyURI"
      select="resolve-uri($href-attr-or-css-url-value, $baseuri)"/>
    <xsl:choose>
      <xsl:when test="unparsed-text-available($resolved, 'UTF-8')">
        <xsl:sequence select="unparsed-text($resolved, 'UTF-8')"/>
      </xsl:when>
      <xsl:when test="unparsed-text-available($resolved, 'UTF-16')">
        <xsl:sequence select="unparsed-text($resolved, 'UTF-16')"/>
      </xsl:when>
      <xsl:when test="unparsed-text-available($resolved, 'CP1252')">
        <xsl:sequence select="unparsed-text($resolved, 'CP1252')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>External stylesheet '<xsl:value-of 
          select="$href-attr-or-css-url-value"/>' (resolved as <xsl:value-of select="$resolved"/>) not found or wrong encoding. 
Supported encodings: UTF-8, UTF-16, CP1252 (the latter should work for ISO-8859-1, too)</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="html:link[@type = 'text/css' or @rel = 'stylesheet']" mode="extract-css" as="element(*)*">
    <xsl:variable name="external-css" as="xs:string?" select="tr:resolve-css-file-content(@href, $base-uri)"/>
    <xsl:variable name="uri" as="xs:string" select="string(resolve-uri(@href, $base-uri))"/>
    <xsl:sequence select="if($external-css)
                          then tr:extract-css($external-css, $uri, $remove-comments = 'yes')/css
                          else ()"/>
  </xsl:template>

  <xsl:template match="html:style" mode="extract-css" as="element(css)?">
    <xsl:sequence select="tr:extract-css(string(.), 'file://internal', $remove-comments = 'yes')/css" />
  </xsl:template>

  <xsl:function name="tr:extract-css" as="document-node(element(css))?">
    <xsl:param name="raw-css" as="xs:string?"/>
    <xsl:param name="origin" as="xs:string"/>
    <xsl:param name="strip-comments" as="xs:boolean"/>
    <xsl:variable name="with-comments-stripped-conditionally" as="xs:string"
      select="if($strip-comments) then replace($raw-css, '/\*.*?\*/', '', 's') else $raw-css"/>
    <xsl:variable name="parser-result" as="element(css)?">
      <xsl:call-template name="main">
        <!--<xsl:with-param name="input" select="if(contains($origin, 'internal'))
                                             then concat('{', normalize-space($raw-css),'}')
                                             else $origin"/>-->
        <xsl:with-param name="input" select="concat('{', $with-comments-stripped-conditionally, '}')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="with-imports-unexpanded" as="document-node(element(css))?">
      <xsl:for-each select="$parser-result">
        <xsl:document>
          <xsl:copy>
            <xsl:attribute name="origin" select="$origin"/>
            <xsl:copy-of select="@*, node()"/>
          </xsl:copy>
        </xsl:document>
      </xsl:for-each>
    </xsl:variable>
    <xsl:document>
      <xsl:apply-templates select="$with-imports-unexpanded" mode="expand-imports">
        <xsl:with-param name="origin" tunnel="yes" as="xs:string" select="$origin"/>
      </xsl:apply-templates>
    </xsl:document>
  </xsl:function>
  
  <xsl:template match="node() | @*" mode="expand-imports">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="import" mode="expand-imports">
    <xsl:param name="origin" tunnel="yes" as="xs:string"/>
    <xsl:variable name="url-container" as="element(*)" select=".//QUOTED_STRING|.//BARE_URL"/>
    <xsl:variable name="imported-css" 
      select="tr:resolve-css-file-content(tr:string-content($url-container), $origin)"/>
    <xsl:copy-of select="."/>
    <xsl:sequence select="tr:extract-css(
                            $imported-css, 
                            resolve-uri(tr:string-content($url-container), $origin),
                            $remove-comments = 'yes'
                          )/css"/>
  </xsl:template>
  
  <xsl:function name="tr:string-content" as="xs:string">
    <xsl:param name="string" as="element(*)"/><!-- QUOTED_STRING or BARE_URL -->
    <xsl:sequence select="string($string/(STRING_CONTENT1 | STRING_CONTENT2 | BARE_URL_CHARS))"/>
  </xsl:function>
  
  <xsl:variable name="css:pseudo-classes-regex" select="':(first-child|last-child|link|visited|hover|active|focus|lang|first-line|first-letter|before|after)'" as="xs:string"/>

  <xsl:function name="tr:resolve-attributes" as="xs:string">
    <xsl:param name="var-resolve-attributes" as="element(attrib)" />
    <xsl:variable name="quots">"</xsl:variable>
    <xsl:variable name="attribute" select="$var-resolve-attributes/*:IDENT[1][preceding-sibling::*[1][self::*:TOKEN[matches(.,'\[')]]]"/>
    <xsl:variable name="value" select="replace($var-resolve-attributes/*[following-sibling::*[1][self::TOKEN[matches(.,'\]')]]],$quots,'')"/>
    <xsl:variable name="token" select="$var-resolve-attributes/descendant::*:TOKEN[not(matches(.,'\[|\]'))]"/>
    <xsl:variable name="atts_declaration">
      <xsl:choose>
        <xsl:when test="not ($token) or $token = ''">
          <xsl:text>exists(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>)</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '='">
          <xsl:text>@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>='</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>'</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '~='">
          <xsl:text>matches(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>,'(^|\s)</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>(\s|$)')</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '|='">
          <xsl:text>matches(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>,'^</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>&#x2d;?$')</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '^='">
          <xsl:text>matches(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>,'^</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>')</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '$='">
          <xsl:text>matches(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>,'</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>$')</xsl:text>
        </xsl:when>
        <xsl:when test="$token = '*='">
          <xsl:text>matches(@</xsl:text>
          <xsl:value-of select="$attribute"/>
          <xsl:text>,'</xsl:text>
          <xsl:value-of select="$value"/>
          <xsl:text>')</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$var-resolve-attributes"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="string-join($atts_declaration, '')"/>
  </xsl:function>

  
  <xsl:function name="tr:getPriority" as="xs:string">
    <xsl:param name="selector" as="element(selector)" />
    <xsl:variable name="tokens" as="xs:string+">
      <!--a, @style-->
      <xsl:sequence select="if ($selector/ancestor::mediaquery) then '1' else '0'" />
      <!--b, count id attributes-->
      <xsl:sequence select="string(count($selector/descendant::HASH))" />
      <!--c, count attributes and pseudo-classes-->
      <xsl:sequence select="string(count($selector/(descendant::attrib | descendant::class
        | descendant::pseudo[matches(.,'first-child|last-child|link|visited|hover|active|focus|lang')])))" />
      <!--d, count elements and pseudo-elements-->
      <xsl:sequence select="string(count($selector/(descendant::type_selector | descendant::NOT
        | descendant::pseudo[matches(.,'first-line|first-letter|before|after')])))" />
    </xsl:variable>
    <xsl:sequence select="string-join($tokens, ',')"></xsl:sequence>
  </xsl:function>

  <!-- mode post-process -->
  
  <xsl:template match="S | atrule 
                       | TOKEN[matches(.,'[\{\[}\]\};]|@page')]
                       | simple_atrule[not(TOKEN[1] = '@import')]" mode="post-process"/>
  
  <xsl:template match="COMMENT" mode="post-process">
    <comment>
      <xsl:attribute name="xml:space" select="'preserve'"/>
      <xsl:copy-of select="ancestor::css[1]/@origin"/>
      <xsl:value-of select="."/>
    </comment>
  </xsl:template>
  
  <xsl:template match="mediaquery" mode="post-process">
    <atrule type="media">
      <xsl:copy-of select="ancestor::css[1]/@origin"/>
      <raw-css>
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:value-of select="."/>
      </raw-css>
      <xsl:apply-templates mode="#current"/>
    </atrule>
  </xsl:template>
  
  <xsl:template match="printcssquery" mode="post-process">
    <atrule type="print">
      <xsl:copy-of select="ancestor::css[1]/@origin"/>
      <raw-css>
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:value-of select="."/>
      </raw-css>
      <xsl:apply-templates mode="#current"/>
    </atrule>
  </xsl:template>

  <xsl:template match="printcssrule | pagearea | arearule" mode="post-process">
    <condition>
      <xsl:value-of select="normalize-space(.)"/>
    </condition>
  </xsl:template>
  
  <xsl:template match="mediarule" mode="post-process">
    <condition>
      <xsl:value-of select="normalize-space(.)"/>
    </condition>
    <xsl:for-each select="media_query_list">
      <xsl:apply-templates select="media_query" mode="#current"/>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="media_query | media_type | media_feature_expression | media_feature_name
                       | and | not | only | value | TOKEN | DIMENSION" mode="post-process">
    <xsl:element name="{name()}">
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="IDENT" mode="post-process">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="media_type/TOKEN" mode="post-process">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="and/TOKEN | not/TOKEN | only/TOKEN | media_feature_expression/TOKEN" mode="post-process"/>
  
  <xsl:template match="media_feature_expression/value | notonly" mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  
  <xsl:template match="query_declaration | pagerule " mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:template match="parser-results" mode="post-process">
    <!-- Note that this css element is in a different namespace than the css element that comes out of expand-css -->
    <css>
      <xsl:apply-templates mode="#current"/>
    </css>
  </xsl:template>
  
  <xsl:template match="import" mode="post-process">
    <atrule type="import" resolved="{exists(following-sibling::*[1]/self::css)}">
      <xsl:copy-of select="ancestor::css[1]/@origin"/>
      <raw-css>
        <xsl:attribute name="xml:space" select="'preserve'"/>
        <xsl:value-of select="."/>
      </raw-css>
    </atrule>
  </xsl:template>
  
  <xsl:template match="css" mode="post-process">
    <xsl:apply-templates mode="#current">
      <xsl:with-param name="origin" tunnel="yes" select="@origin"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*:rule | *:pagequery | *:areaquery" mode="post-process">
    <xsl:param name="origin" tunnel="yes"/>
    <xsl:element name="{if (descendant::*:atrule or self::*:pagequery or self::areaquery) then 'atrule' else 'ruleset'}" namespace="http://www.w3.org/1996/css">
      <xsl:attribute name="origin" select="$origin"/>
      <xsl:if test="descendant::*:atrule or self::*:pagequery">
        <xsl:attribute name="type" select="descendant::*:atrule/*:IDENT"/>
      </xsl:if>
      <xsl:if test="self::*:pagequery">
        <xsl:attribute name="type" select="'page'"/>
      </xsl:if>
      <xsl:if test="self::*:areaquery">
        <xsl:attribute name="type" select="'area'"/>
      </xsl:if>
      <raw-css xml:space="preserve">
        <xsl:value-of select="."/>
      </raw-css>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="declaration" mode="post-process">
    <xsl:param name="origin" tunnel="yes" as="xs:string"/>
    <xsl:variable name="_value" select="values" as="element(values)?"/>
    <xsl:variable name="property" select="property/IDENT" as="xs:string"/>
    <xsl:variable name="pos" as="xs:integer" select="tr:index-of(../declaration, .)"/>
    <xsl:for-each select="$_value">
      <xsl:choose>
        <xsl:when test="$property = $css-shorthand-properties">
          <shorthand property="{$property}" value="{string($_value)}" num="{$pos}"/>
          <xsl:apply-templates select=".." mode="expand-shorthands"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="declaration">
            <xsl:attribute name="property" select="$property"/>
            <xsl:attribute name="value" select="current()"/>
            <xsl:for-each-group select="value/*" group-starting-with="URL">
              <xsl:if test="exists(self::URL)">
                <xsl:element name="resource">
                  <xsl:attribute name="src" 
                    select="resolve-uri(
                              tr:string-content(.//QUOTED_STRING|.//BARE_URL), 
                              ($origin[not(. = 'file://internal')], $base-uri)[1]
                            )"/>
                  <xsl:variable name="format" as="element(functional_pseudo)?" 
                    select="current-group()/self::functional_pseudo[FUNCTION = 'format(']"/>
                  <xsl:if test="exists($format)">
                    <xsl:attribute name="format"
                      select="tr:string-content($format//QUOTED_STRING)"/>
                  </xsl:if>
                </xsl:element>    
              </xsl:if>
            </xsl:for-each-group>
            <xsl:variable name="url-container" as="element(*)?" select=".//QUOTED_STRING|.//BARE_URL"/>
            <xsl:if test="exists($url-container)">
              
            </xsl:if>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="declaration" mode="expand-shorthands">
    <xsl:sequence select="tr:handle-shorthand-properties(property/IDENT, values, string(tr:index-of(../declaration, .)))"/>
  </xsl:template>
  
  <xsl:template match="selectors_group" mode="post-process">
    <xsl:for-each-group select="*" group-starting-with="COMMA">
      <xsl:apply-templates select="current-group()/self::selector" mode="#current"/>
    </xsl:for-each-group>
  </xsl:template>
  
  <xsl:function name="tr:selector-text" as="xs:string">
    <xsl:param name="elts" as="element(*)+"/>
    <xsl:variable name="pieces" as="xs:string+">
      <xsl:for-each select="$elts">
        <xsl:choose>
          <xsl:when test="self::COMMA | self::S"/>
          <xsl:otherwise>
            <xsl:sequence select="string(.)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="string-join($pieces, '')"/>
  </xsl:function>
  
  <xsl:template match="element_name" mode="post-process">
    <xsl:text>*:</xsl:text>
    <xsl:value-of select="IDENT"/>  
  </xsl:template>
  
  <xsl:template match="*:pseudo" mode="post-process"/>
  
  <xsl:template match="*:pseudo[tokenize(*:IDENT, '\s+') = 'first-child']" mode="post-process">
    <xsl:text>[index-of(for $e in ../* return generate-id($e), generate-id()) = 1]</xsl:text>
  </xsl:template>
  
  <xsl:template match="*:pseudo[tokenize(*:IDENT, '\s+') = 'last-child']" mode="post-process">
    <xsl:text>[index-of(for $e in ../* return generate-id($e), generate-id()) = count(../*)]</xsl:text>
  </xsl:template>
  
  <xsl:template match="simple_selector_sequence/universal" mode="post-process">
    <xsl:text>*</xsl:text>
  </xsl:template>
  
  <xsl:template match="attrib" mode="post-process">
    <xsl:text>[</xsl:text>
    <xsl:sequence select="tr:resolve-attributes(.)"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xsl:template match="type_selector" mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="selector" mode="post-process">
    <selector>
      <xsl:attribute name="priority" select="tr:getPriority(.)"/>
      <xsl:attribute name="position" select="count(preceding-sibling::COMMA) + 1 
                                             + sum(for $r in ../../preceding::rule return count($r/selectors_group/COMMA) + 1)"/>
      <xsl:attribute name="raw-selector" select="tr:selector-text(.)"/>
      <xsl:if test="descendant::*:pseudo">
        <xsl:attribute name="pseudo" select="descendant::*:pseudo/*:IDENT"/>
      </xsl:if>
      <xsl:apply-templates select="simple_selector_sequence[last()]" mode="#current"/>
    </selector>
  </xsl:template>
  
  <xsl:variable name="condition-inducing-pseudos" as="xs:string+"
    select="('first-child', 'last-child')"/>
  
  <xsl:template match="simple_selector_sequence" mode="post-process">
    <xsl:variable name="elements" select="universal | type_selector" as="element(*)*"/>
    <xsl:variable name="attribs" select="attrib" as="element(attrib)*"/>
    <xsl:variable name="other-conditions" as="element(*)*"
      select="class | HASH | pseudo[tokenize(IDENT, '\s+') = $condition-inducing-pseudos]" />
    <xsl:apply-templates select="$elements" mode="#current"/>
    <xsl:if test="empty($elements)">
      <xsl:text>*</xsl:text>
    </xsl:if>
    <xsl:apply-templates select="$attribs" mode="#current"/>
    <xsl:if test="$other-conditions">
      <xsl:text>[. </xsl:text>
      <xsl:apply-templates select="$other-conditions" mode="#current"/>
      <xsl:text>]</xsl:text>  
    </xsl:if>
    <xsl:apply-templates select="preceding-sibling::combinator[1]" mode="#current"/>
  </xsl:template>

  <xsl:template match="simple_selector_sequence/class" mode="post-process">
    <xsl:if test="exists(../following-sibling::combinator) 
                  or 
                  not(
                    count(../class) = 1 
                    and 
                    count(../(* except universal)) = 1
                  )">
      <!-- special optimization for '.foo'-type selectors; keep this in sync with following template -->
      <xsl:text> intersect </xsl:text>
    </xsl:if>
    <xsl:text>key('class', '</xsl:text>
    <xsl:value-of select="*:IDENT"/>
    <xsl:text>')</xsl:text>
  </xsl:template>

  <xsl:template match="simple_selector_sequence[not(following-sibling::combinator)]
                                               [count(class) = 1]
                                               [count(* except universal) = 1]" mode="post-process">
    <xsl:apply-templates select="class" mode="#current"/>
    <xsl:apply-templates select="preceding-sibling::combinator[1]" mode="#current"/>
  </xsl:template>
  
  <xsl:template match="simple_selector_sequence/HASH" mode="post-process">
    <xsl:if test="exists(../following-sibling::combinator) 
                  or 
                  not(
                    count(../HASH) = 1 
                    and 
                    count(../(* except universal)) = 1
                  )">
      <!-- special optimization for '.foo'-type selectors; keep this in sync with following template -->
      <xsl:text> intersect </xsl:text>
    </xsl:if>
    <xsl:text>key('id', '</xsl:text>
    <xsl:value-of select="replace(., '^#', '')"/>
    <xsl:text>')</xsl:text>
  </xsl:template>
  
  <xsl:template match="simple_selector_sequence[not(following-sibling::combinator)]
                                               [count(HASH) = 1]
                                               [count(* except universal) = 1]" mode="post-process">
    <xsl:apply-templates select="HASH" mode="#current"/>
    <xsl:apply-templates select="preceding-sibling::combinator[1]" mode="#current"/>
  </xsl:template>

  <xsl:template match="combinator" mode="post-process">
    <xsl:text> [</xsl:text>
    <!-- Expecting that the first child is either PLUS, TILDE, or S. PLUS and TILDE may
      start with whitespace within. It is important though that the parsing not produce
      any S element before PLUS or TILDE. If it does, this variable needs to be adapted. -->
    <xsl:variable name="type" select="*[1]/name()" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$type = 'GREATER'">
        <xsl:text>parent::</xsl:text>
      </xsl:when>
      <xsl:when test="$type = 'S'">
        <xsl:text>ancestor::</xsl:text>
      </xsl:when>
      <xsl:when test="$type = 'PLUS'">
        <xsl:text>preceding-sibling::*[1]/self::</xsl:text>
      </xsl:when>
      <xsl:when test="$type = 'TILDE'">
        <xsl:text>preceding-sibling::</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:apply-templates select="preceding-sibling::simple_selector_sequence[1]" mode="#current"/>
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="node()" mode="post-process">
    <xsl:copy >
      <xsl:apply-templates select="@*|node()" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <!--  overridden function from css-util -->
  <xsl:function name="tr:handle-shorthand-properties" as="element(*)*" xmlns="http://www.w3.org/1996/css">
    <xsl:param name="prop" as="xs:string"/>
    <xsl:param name="val"/>
    <xsl:param name="id" as="xs:string"/>
    <xsl:variable name="val-seq" select="$val"/>
    <xsl:variable name="out" as="element(*)*">
      <xsl:choose>
        <xsl:when test="$prop=('margin', 'padding', 'border-style', 'border-color', 'border-width')">
          
          <xsl:variable name="new-props">
            <props count="1">
              <top seq="1"/>
              <right seq="1"/>
              <bottom seq="1"/>
              <left seq="1"/>
            </props>
            <props count="2">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="1"/>
              <left seq="2"/>
            </props>
            <props count="3">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="3"/>
              <left seq="2"/>
            </props>
            <props count="4">
              <top seq="1"/>
              <right seq="2"/>
              <bottom seq="3"/>
              <left seq="4"/>
            </props>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="count($val-seq) le 4">
              <xsl:for-each select="$new-props/*:props[number(@count) eq count($val-seq/*:value)]/*">
                <xsl:element name="declaration">
                  <xsl:attribute name="property"
                    select="concat(replace($prop, '-.*$', ''), '-', name(), substring-after($prop, 'border'))"/>
                  <xsl:attribute name="value" select="$val-seq/*:value[position() eq number(current()/@seq)]"/>
                  <xsl:attribute name="shorthand" select="$id"/>
                </xsl:element>
              </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
              <xsl:message>ERROR! There is something wrong with property count in shorthand property "<xsl:value-of
                  select="$prop"/>": <xsl:value-of select="$val"/></xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>

        <xsl:when test="$prop=('border')">
          <xsl:call-template name="border-vals">
            <xsl:with-param name="all-pos" select="'top right bottom left'"/>
            <xsl:with-param name="val" select="$val-seq"/>
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>
        </xsl:when>

        <xsl:when test="matches($prop, '^border-(left|right|top|bottom)$')">
          <xsl:call-template name="border-vals">
            <xsl:with-param name="all-pos" select="substring-after($prop, 'border-')"/>
            <xsl:with-param name="val" select="$val-seq"/>
            <xsl:with-param name="id" select="$id"/>
          </xsl:call-template>
        </xsl:when>

        <xsl:when test="$prop='background'">
          <xsl:variable name="new-vals">
            <vals>
              <image pos-vals="(none|url)"/>
              <attachment pos-vals="(scroll|fixed)"/>
              <repeat pos-vals="^(no-repeat|repeat|repeat-x|repeat-y)"/>
              <color pos-vals="(transparent|\(|[a-z]+|#[0-9a-fA-F]+)"/>
              <position pos-vals="(left|right|top|bottom|center|[.0-9]+(%|em|ex|px|in|cm|mm|pt|pc))"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize(replace($val-seq, ',\s', ','), ' ')">
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:image/@pos-vals)">image</xsl:when>
                <xsl:when test="matches(., $new-vals//*:attachment/@pos-vals)">attachment</xsl:when>
                <xsl:when test="matches(., $new-vals//*:repeat/@pos-vals)">repeat</xsl:when>
                <xsl:when test="matches(., $new-vals//*:position/@pos-vals)">position</xsl:when>
                <xsl:when test="matches(., $new-vals//*:color/@pos-vals)">color</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:element name="declaration">
              <xsl:attribute name="property" select="concat('background-', $current-val)"/>
              <xsl:attribute name="value" select="."/>
              <xsl:attribute name="shorthand" select="$id"/>
            </xsl:element>
          </xsl:for-each>
        </xsl:when>

        <xsl:when test="$prop='font'">
          <xsl:variable name="tokens" select="$val-seq/*:value"/>
          <xsl:variable name="value-before-comma" as="element()*" 
            select="($tokens[following-sibling::*[empty(self::*:S) (: the parser currently can’t cope with comments 
            in props, otherwise these must be excluded, too :)][1]/self::*:COMMA])[1]"/>
          <xsl:variable name="font-family" as="element()+"
            select="if ($value-before-comma) then ($value-before-comma, $tokens[. >> $value-before-comma])
                    else $tokens[last()]"/>
          <xsl:variable name="line-height" as="element()?" select="$tokens[preceding-sibling::*[1]/self::TOKEN[. = '/']]"/>
          <xsl:variable name="font-size" as="element()" 
            select="if ($line-height) then $line-height/preceding-sibling::*:value[1]
                    else $font-family[1]/preceding-sibling::*:value[1]"/>
          <xsl:variable name="font-style-unambiguous" select="$tokens[$font-size >> .][*:IDENT = ('italic', 'oblique')]"/>
          <xsl:variable name="font-variant-unambiguous" select="$tokens[$font-size >> .][*:IDENT = ('small-caps')]"/>
          <xsl:variable name="font-weight-unambiguous" 
            select="$tokens[$font-size >> .][*:IDENT = ('bold', 'bolder', 'lighter')
                                             or *:NUMBER[matches(., '^[1-9]00$')]]"/>
          <xsl:variable name="font-stretch-unambiguous" 
            select="$tokens[$font-size >> .][*:IDENT = ('ultra-condensed', 'extra-condensed', 'condensed', 'semi-condensed', 
                                                        'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded') 
                                             or *:PERCENTAGE]"/>
          <declaration property="font-style" value="{($font-style-unambiguous, 'normal')[1]}" shorthand="{$id}"/>
          <declaration property="font-variant" value="{($font-variant-unambiguous, 'normal')[1]}" shorthand="{$id}"/>
          <declaration property="font-weight" value="{($font-weight-unambiguous, 'normal')[1]}" shorthand="{$id}"/>
          <declaration property="font-stretch" value="{($font-stretch-unambiguous, 'normal')[1]}" shorthand="{$id}"/>
          <declaration property="font-size" value="{$font-size}" shorthand="{$id}"/>
          <declaration property="line-height" value="{($line-height, 'normal')[1]}" shorthand="{$id}"/>
          <declaration property="font-family" value="{string-join($font-family, ', ')}" shorthand="{$id}"/>
        </xsl:when>

        <xsl:when test="$prop='list-style'">
          <xsl:variable name="new-vals">
            <vals>
              <type
                pos-vals="(circle|square|disc|decimal|lower-roman|upper-roman|decimal-leading-zero|lower-greek|lower-latin|upper-latin|armenian|georgian|none)"/>
              <position pos-vals="(inside|outside)"/>
              <image pos-vals="(none|url)"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize($val, ' ')">
            <xsl:variable name="current-pos" select="position()"/>
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:position/@pos-vals)">position</xsl:when>
                <xsl:when
                  test="matches(., $new-vals//*:type/@pos-vals) and (not(. eq 'none' and (exists(tokenize($val, ' ')[position() ne $current-pos][matches(., $new-vals//*:type/@pos-vals)]))) or (. eq 'none' and (exists(tokenize($val, ' ')[position() gt $current-pos][. eq 'none']))))"
                  >type</xsl:when>
                <xsl:when test="matches(., $new-vals//*:image/@pos-vals)">image</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
              <xsl:attribute name="property" select="concat('list-style-', $current-val)"/>
              <xsl:attribute name="value" select="."/>
              <xsl:attribute name="shorthand" select="$id"/>
            </xsl:element>
          </xsl:for-each>
        </xsl:when>

        <xsl:when test="$prop='text-decoration'">
          <xsl:variable name="new-vals">
            <vals>
              <style pos-vals="(solid|double|dotted|dashed|wavy)"/>
              <line pos-vals="(none|underline|overline|line-through|blink)"/>
              <color pos-vals="(transparent|\(|[a-z]+|#[0-9a-fA-F]+)"/>
            </vals>
          </xsl:variable>
          <xsl:for-each select="tokenize(replace($val, ',\s', ','), ' ')">
            <xsl:variable name="current-val">
              <xsl:choose>
                <xsl:when test="matches(., $new-vals//*:style/@pos-vals)">style</xsl:when>
                <xsl:when test="matches(., $new-vals//*:line/@pos-vals)">line</xsl:when>
                <xsl:when test="matches(., $new-vals//*:color/@pos-vals)">color</xsl:when>
                <xsl:otherwise/>
              </xsl:choose>
            </xsl:variable>
            <xsl:if test="$current-val">
              <!--<css:declaration/>-->
              <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
                <xsl:attribute name="property" select="concat('text-decoration-', $current-val)"/>
                <xsl:attribute name="value" select="."/>
                <xsl:attribute name="shorthand" select="$id"/>
              </xsl:element>
            </xsl:if>
          </xsl:for-each>
        </xsl:when>

        <xsl:otherwise>
          <xsl:message>WARNING! Shorthand property "<xsl:value-of select="$prop"/>" has not been implemented, yet!</xsl:message>
          <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
            <xsl:attribute name="property" select="$prop"/>
            <xsl:attribute name="value" select="$val"/>
            <xsl:attribute name="shorthand" select="$id"/>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="empty($out)">
      <xsl:message select="'Empty compound prop expansion for prop ', $prop, ' with value ', $val"/>
    </xsl:if>
    <xsl:sequence select="$out"/>
  </xsl:function>
  
  <!--~
   ! The (simple) main program. We needed to overwrite it because we pass multiline strings with stripped comments and 
   therefore need the 's' option with matches()
  -->
  <xsl:template name="main">
    <xsl:param name="input" as="xs:string?" select="$input"/>

    <xsl:choose>
      <xsl:when test="empty($input)">
        <xsl:sequence select="error(xs:QName('main'), '&#xA;    Usage: java net.sf.saxon.Transform -xsl:CSS3.xslt -it:main input=INPUT&#xA;&#xA;      parse INPUT, which is either a filename or literal text enclosed in curly braces')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="result" select="
          if (matches($input, '^\{.*\}$', 's')) then
            p:parse-css(substring($input, 2, string-length($input) - 2))
          else
            p:parse-css(unparsed-text($input, 'utf-8'))
        "/>
        <xsl:sequence select="
          if (empty($result/self::ERROR)) then
            $result
          else
            error(xs:QName('p:parse-css'), concat('&#10;    ', replace($result, '&#10;', '&#10;    ')))
        "/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  
</xsl:stylesheet>