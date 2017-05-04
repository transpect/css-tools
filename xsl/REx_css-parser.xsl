<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xslout="bogo"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tr="http://transpect.io"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:css="http://www.w3.org/1996/css"
  version="2.0"
  exclude-result-prefixes="xs"
  xmlns="http://www.w3.org/1996/css">

  <xsl:import href="css-util.xsl"/>
  <xsl:import href="CSS3.xsl"/>
  
  <xsl:output indent="yes" />

  <xsl:param name="base-uri" select="base-uri(/*)" as="xs:string" />
  
  <xsl:template match="/">
    <css xmlns="http://www.w3.org/1996/css">
      <xsl:choose>
        <xsl:when test="matches(base-uri(/*), '^file:/')">
          <xsl:attribute name="xml:base" select="base-uri(/*)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'Spurious base URI: ', base-uri(/*)"/>      
        </xsl:otherwise>
      </xsl:choose>
      
<!--      <css xmlns="http://www.w3.org/1996/css" xml:base="{base-uri(/*)}">-->
      <xsl:variable name="extracted-css">
				<xsl:apply-templates select="html:html/html:head/(html:link[@rel eq 'stylesheet'] union html:style)" mode="extract-css" />
			</xsl:variable>
      <xsl:variable name="post-processed-css">
  			<xsl:apply-templates select="$extracted-css" mode="post-process">
			   <xsl:with-param name="origin" select="resolve-uri(html:html/html:head/html:link[@rel eq 'stylesheet']/@href, $base-uri)" tunnel="yes"/>
	   		</xsl:apply-templates> 
      </xsl:variable>
      <xsl:apply-templates select="$post-processed-css" mode="add-position"/>
    </css>
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
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="unparsed-text-available($resolved, 'CP1252')">
            <xsl:sequence select="unparsed-text($resolved, 'CP1252')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>External stylesheet '<xsl:value-of select="$href-attr-or-css-url-value"/>' 
(resolved as <xsl:value-of select="$resolved"/>) not found
or wrong encoding. Supported encodings: UTF-8, CP1252 (the latter should work for ISO-8859-1, too)</xsl:message>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="html:link[@type eq 'text/css']" mode="extract-css" as="element(*)*">
    <xsl:variable name="external-css" as="xs:string?"
      select="tr:resolve-css-file-content(@href, $base-uri)"/>
    <xsl:sequence select="if($external-css)
                          then tr:extract-css($external-css, resolve-uri(@href, $base-uri))
                          else ()"/>
  </xsl:template>

  <xsl:template match="html:style" mode="extract-css">
    <xsl:sequence select="tr:extract-css(string-join(for $n in node() return $n, ''), 'file://internal')" />
  </xsl:template>

  <xsl:function name="tr:extract-css" as="element(*)*">
    <xsl:param name="raw-css" as="xs:string?"/>
    <xsl:param name="origin" as="xs:string"/>
    <xsl:call-template name="main">
      <xsl:with-param name="input" select="if (matches($origin,'internal')) 
                                           then (concat('{', normalize-space(replace($raw-css,'&#xa;','')),'}')) 
                                           else $origin"/>
    </xsl:call-template>
   </xsl:function>

  <xsl:variable name="css:pseudo-classes-regex" select="':(first-child|last-child|link|visited|hover|active|focus|lang|first-line|first-letter|before|after)'" as="xs:string"/>

  <xsl:function name="tr:resolve-attributes" as="xs:string">
    <xsl:param name="var-resolve-attributes" />
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
          <xsl:value-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="string-join($atts_declaration, '')"/>
  </xsl:function>

  
  <xsl:function name="tr:getPriority">
    <xsl:param name="selector" />
    <!--a, @style-->
    <xsl:value-of select="'0'" />
    <xsl:text>,</xsl:text>
    <!--b, count id attributes-->
    <xsl:value-of select="count($selector/descendant::*:HASH)" />
    <xsl:text>,</xsl:text>
    <!--c, count attributes and pseudo-classes-->
    <xsl:value-of select="count($selector/descendant::*:attrib)
      + count($selector/descendant::*:pseudo[matches(.,'first-child|last-child|link|visited|hover|active|focus|lang')])" />
    <xsl:text>,</xsl:text>
    <!--d, count elements and pseudo-elements-->
    <xsl:value-of select="count($selector/descendant::*:combinator) + count($selector/descendant::*:pseudo[matches(.,'first-line|first-letter|before|after')])" />
  </xsl:function>

  <!-- mode post-process -->
  
  <xsl:template match="*:S |*:TOKEN[matches(.,'[\{\[}\]\};]')]| *:atrule" mode="post-process"/>
  
  <xsl:template match="*:css" mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="*:rule" mode="post-process">
    <xsl:param name="origin" tunnel="yes"/>
    <xsl:element name="{if (descendant::*:atrule) then 'atrule' else 'ruleset'}" namespace="http://www.w3.org/1996/css">
      <xsl:attribute name="origin" select="$origin  "/>
      <xsl:if test="descendant::*:atrule">
        <xsl:attribute name="type" select="descendant::*:atrule/*:IDENT"/>
      </xsl:if>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="*:declaration" mode="post-process">
    <xsl:variable name="value" select="*:values"/>
    <xsl:variable name="property" select="*:property/*/text()"/>
    <xsl:for-each select="$value">
      <xsl:choose>
        <xsl:when test="$property = $css-shorthand-properties">
         <xsl:sequence select="tr:handle-shorthand-properties($property, current(), string(position()))" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="declaration">
            <xsl:attribute name="property" select="$property"/>
            <xsl:attribute name="value" select="current()"/>
            <xsl:variable name="css-url-regex" select="'.*?url\(''?(.+?)''?\).*'" as="xs:string"/>
            <xsl:for-each select="current()/*:URL">
              <xsl:element name="resource">
                <xsl:attribute name="src" select="resolve-uri(replace(current(),$css-url-regex,'$1'), $base-uri)"/>
              </xsl:element>
            </xsl:for-each>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="*:selectors_group" mode="post-process">
    <xsl:element name="selector">
       <xsl:attribute name="priority" select="tr:getPriority(*:selector)" />
      <xsl:attribute name="raw-selector" select="string-join(descendant::text(),'')"/>
      <xsl:if test="descendant::*:pseudo">
        <xsl:attribute name="pseudo" select="descendant::*:pseudo/*:IDENT"/>
      </xsl:if>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="*:element_name" mode="post-process">
    <xsl:param name="condition" tunnel="yes"/>
    <xsl:sequence select="concat('*:', .)"/>
    <xsl:if test="$condition">
      <xsl:text>]</xsl:text>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="*:pseudo" mode="post-process">
    <xsl:text>[@css:pseudo_</xsl:text>
    <xsl:value-of select="*:IDENT"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xsl:template match="*:simple_selector_sequence/*:HASH" mode="post-process">
      <xsl:sequence select="if (preceding::*[1]/descendant-or-self::*:IDENT) 
                          then '['
                          else '*['"/>
    <xsl:text>@id='</xsl:text>
    <xsl:value-of select="replace(.,'#','')"/>  
    <xsl:text>']</xsl:text>
  </xsl:template>
  
    
  <xsl:template match="*:simple_selector_sequence/*:class" mode="post-process">
      <xsl:sequence select="if (preceding::*[1]/descendant-or-self::*:IDENT) 
                          then '['
                          else '*['"/>
      <xsl:text>matches(@class</xsl:text>
      <xsl:text>,'(^|\s)</xsl:text>
      <xsl:value-of select="*:IDENT"/>  
      <xsl:text>(\s|$)')</xsl:text>
      <xsl:text>]</xsl:text>
  </xsl:template>
  
    <xsl:template match="*:simple_selector_sequence/*:universal" mode="post-process">
    <xsl:text>*</xsl:text>
  </xsl:template>
  
  <xsl:template match="*:selector/*:combinator" mode="post-process">
    <xsl:choose>
      <xsl:when test="matches(.,'>')">
        <xsl:text>/</xsl:text>
      </xsl:when>
        <xsl:when test="matches(.,' ')">
        <xsl:text>[ancestor::</xsl:text>
      </xsl:when>
         <xsl:when test="matches(.,'\+')">
        <xsl:text>/preceding::*[1]/self::</xsl:text>
      </xsl:when>
       <xsl:when test="matches(.,'~')">
        <xsl:text>[preceding-sibling::</xsl:text>
      </xsl:when>
      <xsl:when test="matches(.,'\,')">
        <xsl:text>|</xsl:text>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*:attrib" mode="post-process">
    <xsl:sequence select="if (preceding::*[1]/descendant-or-self::*:IDENT) 
                          then '['
                          else '*['"/><xsl:sequence select="tr:resolve-attributes(.)"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xsl:template match="*:simple_selector_sequence|*:type_selector" mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <!--  reorder simple_selector_sequence according to it's xpath (e.g. combinator ' ' in ancestor::)-->
  <xsl:template match="*:selector[*:combinator[matches(descendant::text(),' |~')]]" mode="post-process">
    <xsl:param name="condition" tunnel="yes"/>
    <xsl:apply-templates  select="*:simple_selector_sequence[preceding-sibling::*:combinator]" mode="#current">
    </xsl:apply-templates>
    <xsl:apply-templates  select="*:combinator" mode="#current"/>
    <xsl:apply-templates  select="*:simple_selector_sequence[following-sibling::*:combinator]" mode="#current">
      <xsl:with-param name="condition" select="true()" tunnel="yes"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*:COMMA" mode="post-process">
      <xsl:text>|</xsl:text>
  </xsl:template>
  
  <xsl:template match="*:selector" mode="post-process">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <!--
 <xsl:template match="*:mediaquery" mode="post-process">
   ?
  </xsl:template>
  -->
  
  <!-- mode add-position -->
  
  <xsl:template match="node()" mode="add-position post-process">
    <xsl:copy >
      <xsl:apply-templates select="@*|node()" mode="#current" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@*" mode="add-position">
    <xsl:copy-of select="." />
  </xsl:template>

  <xsl:template match="*:selector" mode="add-position">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current" />
      <xsl:attribute name="position" select="count(parent::*:ruleset/preceding-sibling::*:ruleset)+1" />
      <xsl:apply-templates select="node()" mode="#current" />
    </xsl:copy>
  </xsl:template>
  
  <!--  overwritten function from css-util -->
  <xsl:function name="tr:handle-shorthand-properties" as="element(*)*">
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
                <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
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
            <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
              <xsl:attribute name="property" select="concat('background-', $current-val)"/>
              <xsl:attribute name="value" select="."/>
              <xsl:attribute name="shorthand" select="$id"/>
            </xsl:element>
          </xsl:for-each>
        </xsl:when>

        <xsl:when test="$prop='font'">
          <xsl:variable name="tokens" select="$val-seq/*:value"/>
          
          <xsl:choose>
            <xsl:when test="count($tokens) = 2">
              <!-- token 1 is size, token 2 is family -->
              <declaration xmlns="http://www.w3.org/1996/css" property="font-size" value="{$tokens[1]}" shorthand="{$id}"/>
              <declaration xmlns="http://www.w3.org/1996/css" property="font-family" value="{$tokens[2]}" shorthand="{$id}"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:for-each select="('style', 'weight', 'size' , 'line-height', 'family')">
                <xsl:variable name="current-pos" select="position()"/>
                <xsl:element name="declaration" xmlns="http://www.w3.org/1996/css">
                  <xsl:attribute name="property" select="if (current() = 'line-height') then current() else concat('font-', .)"/>
                  <xsl:choose>
                    <xsl:when test="$val/*:value = 'inherit'">
                      <xsl:attribute name="value" select="$val"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:attribute name="value"
                        select="$tokens[if ($current-pos le 4) then (position() eq $current-pos) else (position() ge 5)]"/>
                    </xsl:otherwise>
                  </xsl:choose>
                  <xsl:attribute name="shorthand" select="$id"/>
                </xsl:element>
              </xsl:for-each>
            </xsl:otherwise>
          </xsl:choose>
          
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
  
</xsl:stylesheet>